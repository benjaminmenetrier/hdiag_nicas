!----------------------------------------------------------------------
! Program: main
!> Purpose: initialization, drivers, finalization
!> <br>
!> Author: Benjamin Menetrier
!> <br>
!> Licensing: this code is distributed under the CeCILL-C license
!> <br>
!> Copyright © 2017 METEO-FRANCE
!----------------------------------------------------------------------
program main

use driver_hdiag, only: run_hdiag
use driver_lct, only: run_lct
use driver_nicas, only: run_nicas
use driver_obsgen, only: run_obsgen
use driver_obsop, only: run_obsop
use model_interface, only: model_coord,load_ensemble
use tools_display, only: listing_setup,msgerror
use tools_kinds,only: kind_real
use type_bpar, only: bpar_type
use type_cmat, only: cmat_type
use type_geom, only: geom_type
use type_mpl, only: mpl,mpl_start,mpl_end
use type_nam, only: nam_type
use type_nicas, only: nicas_type
use type_obsop, only: obsop_type
use type_rng, only: rng
use type_timer, only: timer_type

implicit none

! Local variables
real(kind_real),allocatable :: ens1(:,:,:,:,:)
type(geom_type),target :: geom
type(nam_type),target :: nam
type(bpar_type) :: bpar
type(cmat_type) :: cmat
type(nicas_type) :: nicas
type(obsop_type) :: obsop
type(timer_type) :: timer

!----------------------------------------------------------------------
! Initialize MPL
!----------------------------------------------------------------------

call mpl_start()

!----------------------------------------------------------------------
! Initialize timer
!----------------------------------------------------------------------

if (mpl%main) call timer%start

!----------------------------------------------------------------------
! Read namelist
!----------------------------------------------------------------------

call nam%read

!----------------------------------------------------------------------
! Setup display
!----------------------------------------------------------------------

call listing_setup(nam%colorlog,nam%logpres)

!----------------------------------------------------------------------
! Header
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- You are running hdiag_nicas -----------------------------------'
write(mpl%unit,'(a)') '--- Author: Benjamin Menetrier ------------------------------------'
write(mpl%unit,'(a)') '--- Copyright © 2017 METEO-FRANCE ---------------------------------'
write(mpl%unit,'(a)') '-------------------------------------------------------------------'

!----------------------------------------------------------------------
! Check namelist
!----------------------------------------------------------------------

call nam%check

!----------------------------------------------------------------------
! Parallel setup
!----------------------------------------------------------------------

write(mpl%unit,'(a,i4,a,i4,a)') '--- Parallelization with ',mpl%nproc,' MPI tasks and ',mpl%nthread,' OpenMP threads'

!----------------------------------------------------------------------
! Initialize random number generator
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Initialize random number generator'

call rng%create(nam)

!----------------------------------------------------------------------
! Initialize geometry
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Initialize geometry'

call model_coord(nam,geom)

!----------------------------------------------------------------------
! Initialize block parameters
!----------------------------------------------------------------------

call bpar%alloc(nam,geom)

!----------------------------------------------------------------------
! Compute grid mesh
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Compute grid mesh'

! Compute grid mesh
call geom%compute_grid_mesh(nam)

!----------------------------------------------------------------------
! Load ensemble
!----------------------------------------------------------------------

if (nam%load_ensemble) then
   write(mpl%unit,'(a)') '-------------------------------------------------------------------'
   write(mpl%unit,'(a)') '--- Load ensemble'

   ! Allocation
   allocate(ens1(geom%nc0a,geom%nl0,nam%nv,nam%nts,nam%ens1_ne))

   ! Load ensemble
   call load_ensemble(nam,geom,ens1)
end if

!----------------------------------------------------------------------
! Call HDIAG driver
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Call HDIAG driver'

! HDIAG driver
if (nam%load_ensemble) then
   call run_hdiag(nam,geom,bpar,cmat,ens1)
else
   call run_hdiag(nam,geom,bpar,cmat)
end if

!----------------------------------------------------------------------
! Call NICAS driver
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Call NICAS driver'

! NICAS driver
if (nam%load_ensemble) then
   call run_nicas(nam,geom,bpar,cmat,nicas,ens1)
else
   call run_nicas(nam,geom,bpar,cmat,nicas)
end if

!----------------------------------------------------------------------
! Call LCT driver
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a)') '--- Call LCT driver'

if (nam%load_ensemble) then
   call run_lct(nam,geom,bpar,ens1)
else
   call run_lct(nam,geom,bpar)
end if

!----------------------------------------------------------------------
! Call observation operator driver
!----------------------------------------------------------------------

write(mpl%unit,'(a)') '-------------------------------------------------------------------'
write(mpl%unit,'(a,i5,a)') '--- Call observation operator driver'

call run_obsgen(nam,geom,obsop)
call run_obsop(nam,geom,obsop)

!----------------------------------------------------------------------
! Execution stats
!----------------------------------------------------------------------

if (mpl%main) then
   write(mpl%unit,'(a)') '-------------------------------------------------------------------'
   write(mpl%unit,'(a)') '--- Execution stats'

   call timer%display

   write(mpl%unit,'(a)') '-------------------------------------------------------------------'
else
   write(mpl%unit,'(a)') '-------------------------------------------------------------------'
   write(mpl%unit,'(a)') '--- Done ----------------------------------------------------------'
   write(mpl%unit,'(a)') '-------------------------------------------------------------------'
end if

!----------------------------------------------------------------------
! Close listing files
!----------------------------------------------------------------------

if ((mpl%main.and..not.nam%colorlog).or..not.mpl%main) close(unit=mpl%unit)

!----------------------------------------------------------------------
! Finalize MPL
!----------------------------------------------------------------------

call mpl_end()

end program main
