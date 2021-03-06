!----------------------------------------------------------------------
! Module: type_diag_blk
! Purpose: diagnostic block derived type
! Author: Benjamin Menetrier
! Licensing: this code is distributed under the CeCILL-C license
! Copyright © 2015-... UCAR, CERFACS, METEO-FRANCE and IRIT
!----------------------------------------------------------------------
module type_diag_blk

use netcdf
!$ use omp_lib
use tools_fit, only: fast_fit,ver_fill
use tools_func, only: fit_diag
use tools_kinds, only: kind_real,nc_kind_real,huge_real
use tools_repro, only: inf,sup
use type_avg_blk, only: avg_blk_type
use type_bpar, only: bpar_type
use type_geom, only: geom_type
use type_minim, only: minim_type
use type_mpl, only: mpl_type
use type_nam, only: nam_type
use type_rng, only: rng_type
use type_samp, only: samp_type

implicit none

integer,parameter :: nsc = 50                          ! Number of iterations for the scaling optimization
real(kind_real),parameter :: maxfactor = 2.0_kind_real ! Maximum factor for diagnostics with respect to the origin

! Diagnostic block derived type
type diag_blk_type
   integer :: ic2a                                ! Local index
   integer :: ib                                  ! Block index
   character(len=1024) :: prefix                  ! Prefix

   real(kind_real),allocatable :: raw(:,:,:)      ! Raw diagnostic
   real(kind_real),allocatable :: valid(:,:,:)    ! Number of valid couples
   real(kind_real),allocatable :: coef_ens(:)     ! Ensemble coefficient
   real(kind_real) :: coef_sta                    ! Static coefficient
   real(kind_real),allocatable :: fit(:,:,:)      ! Fit
   real(kind_real),allocatable :: fit_rh(:)       ! Horizontal fit support radius
   real(kind_real),allocatable :: fit_rv(:)       ! Vertical fit support radius
   real(kind_real),allocatable :: distv(:,:)      ! Reduced vertical distance
contains
   procedure :: alloc => diag_blk_alloc
   procedure :: dealloc => diag_blk_dealloc
   procedure :: write => diag_blk_write
   procedure :: normalization => diag_blk_normalization
   procedure :: fitting => diag_blk_fitting
   procedure :: localization => diag_blk_localization
   procedure :: hybridization => diag_blk_hybridization
   procedure :: dualens => diag_blk_dualens
end type diag_blk_type

private
public :: diag_blk_type

contains

!----------------------------------------------------------------------
! Subroutine: diag_blk_alloc
! Purpose: allocation
!----------------------------------------------------------------------
subroutine diag_blk_alloc(diag_blk,mpl,nam,geom,bpar,samp,ic2a,ib,prefix)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block
type(mpl_type),intent(inout) :: mpl            ! MPI data
type(nam_type),intent(in) :: nam               ! Namelist
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters
type(samp_type),intent(in) :: samp             ! Sampling
integer,intent(in) :: ic2a                     ! Local index
integer,intent(in) :: ib                       ! Block index
character(len=*),intent(in) :: prefix          ! Block prefix

! Local variables
integer :: ic0a,il0,jl0
real(kind_real) :: vunit(geom%nl0)

! Set attributes
diag_blk%ic2a = ic2a
diag_blk%ib = ib
diag_blk%prefix = prefix

! Allocation
if ((ic2a==0).or.nam%local_diag) then
   allocate(diag_blk%raw(bpar%nc3(ib),bpar%nl0r(ib),geom%nl0))
   allocate(diag_blk%valid(bpar%nc3(ib),bpar%nl0r(ib),geom%nl0))
   allocate(diag_blk%coef_ens(geom%nl0))
   if (trim(nam%minim_algo)/='none') then
      allocate(diag_blk%fit(bpar%nc3(ib),bpar%nl0r(ib),geom%nl0))
      allocate(diag_blk%fit_rh(geom%nl0))
      allocate(diag_blk%fit_rv(geom%nl0))
      allocate(diag_blk%distv(geom%nl0,geom%nl0))
   end if
end if

! Initialization
diag_blk%coef_sta = mpl%msv%valr
if ((ic2a==0).or.nam%local_diag) then
   diag_blk%raw = mpl%msv%valr
   diag_blk%valid = mpl%msv%valr
   diag_blk%coef_ens = mpl%msv%valr
   if (trim(nam%minim_algo)/='none') then
      diag_blk%fit = mpl%msv%valr
      diag_blk%fit_rh = mpl%msv%valr
      diag_blk%fit_rv = mpl%msv%valr
   end if
end if

! Vertical distance
if (((ic2a==0).or.nam%local_diag).and.(trim(nam%minim_algo)/='none')) then
   if (ic2a==0) then
      vunit = geom%vunitavg
   else
      ic0a = samp%c2a_to_c0a(ic2a)
      vunit = geom%vunit_c0a(ic0a,:)
   end if
   do il0=1,geom%nl0
      do jl0=1,geom%nl0
         diag_blk%distv(jl0,il0) = abs(vunit(il0)-vunit(jl0))
      end do
   end do
end if

end subroutine diag_blk_alloc

!----------------------------------------------------------------------
! Subroutine: diag_blk_dealloc
! Purpose: release memory
!----------------------------------------------------------------------
subroutine diag_blk_dealloc(diag_blk)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block

! Release memory
if (allocated(diag_blk%raw)) deallocate(diag_blk%raw)
if (allocated(diag_blk%valid)) deallocate(diag_blk%valid)
if (allocated(diag_blk%coef_ens)) deallocate(diag_blk%coef_ens)
if (allocated(diag_blk%fit)) deallocate(diag_blk%fit)
if (allocated(diag_blk%fit_rh)) deallocate(diag_blk%fit_rh)
if (allocated(diag_blk%fit_rv)) deallocate(diag_blk%fit_rv)
if (allocated(diag_blk%distv)) deallocate(diag_blk%distv)

end subroutine diag_blk_dealloc

!----------------------------------------------------------------------
! Subroutine: diag_blk_write
! Purpose: write
!----------------------------------------------------------------------
subroutine diag_blk_write(diag_blk,mpl,nam,geom,bpar,filename)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block
type(mpl_type),intent(inout) :: mpl            ! MPI data
type(nam_type),intent(in) :: nam               ! Namelist
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters
character(len=*),intent(in) :: filename        ! File name

! Local variables
integer :: ncid,grpid,subgrpid,one_id,nc3_id,nl0r_id,nl0_1_id,nl0_2_id,disth_id,vunit_id
integer :: raw_id,valid_id,coef_ens_id,raw_zs_id,coef_sta_id,l0rl0_to_l0_id
integer :: fit_id,fit_zs_id,fit_rh_id,fit_rv_id
integer :: il0,jl0r,jl0
character(len=1024),parameter :: subr = 'diag_blk_write'

! Associate
associate(ib=>diag_blk%ib,ic2a=>diag_blk%ic2a)

! Define file
ncid = mpl%nc_file_create_or_open(subr,trim(nam%datadir)//'/'//trim(filename)//'.nc')

! Write namelist parameters
call nam%write(mpl,ncid)

! Define group
grpid = mpl%nc_group_define_or_get(subr,ncid,bpar%blockname(ib))

! Define dimensions
one_id = mpl%nc_dim_define_or_get(subr,ncid,'one',1)
nc3_id = mpl%nc_dim_define_or_get(subr,grpid,'nc3',bpar%nc3(ib))
nl0r_id = mpl%nc_dim_define_or_get(subr,grpid,'nl0r',bpar%nl0r(ib))
nl0_1_id = mpl%nc_dim_define_or_get(subr,ncid,'nl0_1',geom%nl0)
nl0_2_id = mpl%nc_dim_define_or_get(subr,ncid,'nl0_2',geom%nl0)

! Define coordinates
disth_id = mpl%nc_var_define_or_get(subr,grpid,'disth',nc_kind_real,(/nc3_id/))
vunit_id = mpl%nc_var_define_or_get(subr,ncid,'vunit',nc_kind_real,(/nl0_1_id/))

! Define subgroup
subgrpid = mpl%nc_group_define_or_get(subr,grpid,diag_blk%prefix)

! Define variables
if (mpl%msv%isanynot(diag_blk%raw)) then
   raw_id = mpl%nc_var_define_or_get(subr,subgrpid,'raw',nc_kind_real,(/nc3_id,nl0r_id,nl0_1_id/))
   valid_id = mpl%nc_var_define_or_get(subr,subgrpid,'valid',nc_kind_real,(/nc3_id,nl0r_id,nl0_1_id/))
   if (bpar%nl0rmax/=geom%nl0) raw_zs_id = mpl%nc_var_define_or_get(subr,subgrpid,'raw_zs',nc_kind_real,(/nl0_2_id,nl0_1_id/))
   l0rl0_to_l0_id = mpl%nc_var_define_or_get(subr,subgrpid,'l0rl0_to_l0',nf90_int,(/nl0r_id,nl0_1_id/))
end if
if (mpl%msv%isanynot(diag_blk%coef_ens)) coef_ens_id = mpl%nc_var_define_or_get(subr,subgrpid,'coef_ens',nc_kind_real,(/nl0_1_id/))
if (mpl%msv%isnot(diag_blk%coef_sta)) coef_sta_id = mpl%nc_var_define_or_get(subr,subgrpid,'coef_sta',nc_kind_real,(/one_id/))
if ((trim(nam%minim_algo)/='none').and.(mpl%msv%isanynot(diag_blk%fit))) then
   fit_id = mpl%nc_var_define_or_get(subr,subgrpid,'fit',nc_kind_real,(/nc3_id,nl0r_id,nl0_1_id/))
   if (bpar%nl0rmax/=geom%nl0) fit_zs_id = mpl%nc_var_define_or_get(subr,subgrpid,'fit_zs',nc_kind_real,(/nl0_2_id,nl0_1_id/))
   fit_rh_id = mpl%nc_var_define_or_get(subr,subgrpid,'fit_rh',nc_kind_real,(/nl0_1_id/))
   fit_rv_id = mpl%nc_var_define_or_get(subr,subgrpid,'fit_rv',nc_kind_real,(/nl0_1_id/))
end if

! Write coordinates
call mpl%ncerr(subr,nf90_put_var(grpid,disth_id,geom%disth(1:bpar%nc3(ib))))
call mpl%ncerr(subr,nf90_put_var(ncid,vunit_id,geom%vunitavg))

! Write variables
if (mpl%msv%isanynot(diag_blk%raw)) then
   call mpl%ncerr(subr,nf90_put_var(subgrpid,raw_id,diag_blk%raw))
   call mpl%ncerr(subr,nf90_put_var(subgrpid,valid_id,diag_blk%valid))
   if (bpar%nl0rmax/=geom%nl0) then
      do il0=1,geom%nl0
         do jl0r=1,bpar%nl0rmax
            jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)
            call mpl%ncerr(subr,nf90_put_var(subgrpid,raw_zs_id,diag_blk%raw(1,jl0r,il0),(/jl0,il0/)))
         end do
      end do
   end if
   call mpl%ncerr(subr,nf90_put_var(subgrpid,l0rl0_to_l0_id,bpar%l0rl0b_to_l0(1:bpar%nl0r(ib),:,ib)))
end if
if (mpl%msv%isanynot(diag_blk%coef_ens)) call mpl%ncerr(subr,nf90_put_var(subgrpid,coef_ens_id,diag_blk%coef_ens))
if (mpl%msv%isnot(diag_blk%coef_sta)) call mpl%ncerr(subr,nf90_put_var(subgrpid,coef_sta_id,diag_blk%coef_sta))
if ((trim(nam%minim_algo)/='none').and.(mpl%msv%isanynot(diag_blk%fit))) then
   call mpl%ncerr(subr,nf90_put_var(subgrpid,fit_id,diag_blk%fit))
   if (bpar%nl0rmax/=geom%nl0) then
      do il0=1,geom%nl0
         do jl0r=1,bpar%nl0rmax
            jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)
            call mpl%ncerr(subr,nf90_put_var(subgrpid,fit_zs_id,diag_blk%fit(1,jl0r,il0),(/jl0,il0/)))
          end do
        end do
    end if
    call mpl%ncerr(subr,nf90_put_var(subgrpid,fit_rh_id,diag_blk%fit_rh))
    call mpl%ncerr(subr,nf90_put_var(subgrpid,fit_rv_id,diag_blk%fit_rv))
end if

! Close file
call mpl%ncerr(subr,nf90_close(ncid))

! End associate
end associate

end subroutine diag_blk_write

!----------------------------------------------------------------------
! Subroutine: diag_blk_normalization
! Purpose: compute diagnostic block normalization
!----------------------------------------------------------------------
subroutine diag_blk_normalization(diag_blk,geom,bpar)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters

! Local variables
integer :: il0,jl0r

! Associate
associate(ib=>diag_blk%ib)

! Get diagonal values
do il0=1,geom%nl0
   jl0r = bpar%il0rz(il0,ib)
   diag_blk%coef_ens(il0) = diag_blk%raw(1,jl0r,il0)
end do

! End associate
end associate

end subroutine diag_blk_normalization

!----------------------------------------------------------------------
! Subroutine: diag_blk_fitting
! Purpose: compute a fit of a raw function
!----------------------------------------------------------------------
subroutine diag_blk_fitting(diag_blk,mpl,rng,nam,geom,bpar,samp,coef)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block
type(mpl_type),intent(inout) :: mpl            ! MPI data
type(rng_type),intent(inout) :: rng            ! Random number generator
type(nam_type),intent(in) :: nam               ! Namelist
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters
type(samp_type),intent(in) :: samp             ! Sampling
logical,intent(in),optional :: coef            ! Coefficient estimation flag

! Local variables
integer :: ic0a,il0,jl0r,jl0,isc,il0_prev,dl0,il0inf,il0sup,il1inf,il1sup,ivar
real(kind_real) :: alpha,alpha_opt,fo,fo_opt
real(kind_real) :: vunit(geom%nl0),m2(geom%nl0),fit_rh(geom%nl0),fit_rv(geom%nl0)
real(kind_real),allocatable :: rawv(:),distv(:),fit(:,:,:),fit_pack(:),obs_pack(:)
logical :: valid,lcoef,lrh,lrv,var2d
character(len=1024),parameter :: subr = 'diag_blk_fitting'
type(minim_type) :: minim

! Associate
associate(ic2a=>diag_blk%ic2a,ib=>diag_blk%ib)

! Check
if (trim(nam%minim_algo)=='none') call mpl%abort(subr,'cannot compute fit if minim_algo = none')

! Local estimation flags
lcoef = any(diag_blk%coef_ens>0.0)
if (present(coef)) lcoef = coef

! Allocation
allocate(rawv(bpar%nl0r(ib)))
allocate(distv(bpar%nl0r(ib)))
allocate(fit(nam%nc3,bpar%nl0r(ib),geom%nl0))
allocate(fit_pack(nam%nc3*bpar%nl0r(ib)*geom%nl0))
allocate(obs_pack(nam%nc3*bpar%nl0r(ib)*geom%nl0))

! Initialization
diag_blk%fit_rh = mpl%msv%valr
diag_blk%fit_rv = mpl%msv%valr
diag_blk%fit = mpl%msv%valr

! Vertical unit
if (ic2a==0) then
   vunit = geom%vunitavg
else
   ic0a = samp%c2a_to_c0a(ic2a)
   vunit = geom%vunit_c0a(ic0a,:)
end if

! Fast fit
do il0=1,geom%nl0
   ! Get zero separation level
   jl0r = bpar%il0rz(il0,ib)

   ! Horizontal fast fit
   call fast_fit(mpl,nam%nc3,1,geom%disth,diag_blk%raw(:,jl0r,il0),diag_blk%fit_rh(il0))

   ! Vertical fast fit
   rawv = diag_blk%raw(1,:,il0)
   distv = diag_blk%distv(bpar%l0rl0b_to_l0(:,il0,ib),il0)
   call fast_fit(mpl,bpar%nl0r(ib),jl0r,distv,rawv,diag_blk%fit_rv(il0))
end do

! Check for 2D variable
do il0=1,geom%nl0
   ! Get zero separation level
   jl0r = bpar%il0rz(il0,ib)

   ! Get value at zero separation
   m2(il0) = diag_blk%raw(1,jl0r,il0)
end do
var2d = .false.
if (count(m2>0.0)==1) then
   if ((trim(nam%lev2d)=='first').and.(m2(1)>0.0)) then
      var2d = .true.
      diag_blk%fit_rv(1) = 0.0
   elseif ((trim(nam%lev2d)=='last').and.(m2(geom%nl0)>0.0)) then
      var2d = .true.
      diag_blk%fit_rv(geom%nl0) = 0.0
   end if
end if

! Check that there are some non-missing values to work with
valid = .true.
valid = valid.and.(mpl%msv%isanynot(diag_blk%coef_ens))
valid = valid.and.(mpl%msv%isanynot(diag_blk%fit_rh))
valid = valid.and.(mpl%msv%isanynot(diag_blk%fit_rv))

if (valid) then
   ! Fill missing values
   if (mpl%msv%isany(diag_blk%coef_ens)) call ver_fill(mpl,geom%nl0,vunit,diag_blk%coef_ens)
   if (mpl%msv%isany(diag_blk%fit_rh)) call ver_fill(mpl,geom%nl0,vunit,diag_blk%fit_rh)
   if (mpl%msv%isany(diag_blk%fit_rv)) call ver_fill(mpl,geom%nl0,vunit,diag_blk%fit_rv)

   ! Scaling optimization (brute-force)
   fo_opt = huge_real
   alpha_opt = 1.0
   do isc=1,nsc
      ! Scaling factor
      alpha = 0.5+real(isc-1,kind_real)/real(nsc-1,kind_real)*(2.0-0.5)

      ! Scaled radii
      fit_rh = alpha*diag_blk%fit_rh
      fit_rv = alpha*diag_blk%fit_rv

      ! Compute fit
      call fit_diag(mpl,nam%nc3,bpar%nl0r(ib),geom%nl0,bpar%l0rl0b_to_l0(:,:,ib),geom%disth,diag_blk%distv, &
 & diag_blk%coef_ens,fit_rh,fit_rv,fit)

      ! Pack
      fit_pack = pack(fit,mask=.true.)
      obs_pack = pack(diag_blk%raw,mask=.true.)

      ! Observations penalty
      fo = sum((fit_pack-obs_pack)**2,mask=mpl%msv%isnot(obs_pack).and.mpl%msv%isnot(fit_pack))

      if (fo<fo_opt) then
         ! Update cost
         fo_opt = fo
         alpha_opt = alpha
      end if
   end do
   diag_blk%fit_rh = alpha_opt*diag_blk%fit_rh
   diag_blk%fit_rv = alpha_opt*diag_blk%fit_rv

   ! Full optimization

   ! Optimization parameters
   select case (trim(nam%minim_algo))
   case ('hooke')
      ! Hooke parameters
      minim%hooke_rho = 0.5
      minim%hooke_tol = 1.0e-2
      minim%hooke_itermax = 5
   case ('praxis')
      ! Praxis parameters
      minim%praxis_tol = 5.0
      minim%praxis_itermax = 5
   end select
   lrh = any(diag_blk%fit_rh>0.0)
   lrv = any(diag_blk%fit_rv>0.0)

   select case (trim(nam%minim_algo))
   case ('hooke','praxis')
      ! Allocation
      minim%smoothness_penalty = nam%smoothness_penalty
      minim%dl0 = nam%fit_dl0
      minim%nl1 = 1
      il0_prev = 1
      do il0=2,geom%nl0
         dl0 = il0-il0_prev
         if (dl0==minim%dl0) then
            il0_prev = il0
            minim%nl1 = minim%nl1+1
         end if
      end do
      minim%nx = 0
      if (lcoef) minim%nx = minim%nx+minim%nl1
      if (lrh) minim%nx = minim%nx+minim%nl1
      if (lrv) minim%nx = minim%nx+minim%nl1
      minim%ny = nam%nc3*bpar%nl0r(ib)*geom%nl0
      allocate(minim%il1inf(geom%nl0))
      allocate(minim%rinf(geom%nl0))
      allocate(minim%il1sup(geom%nl0))
      allocate(minim%rsup(geom%nl0))
      allocate(minim%x(minim%nx))
      allocate(minim%guess(minim%nx))
      allocate(minim%binf(minim%nx))
      allocate(minim%bsup(minim%nx))
      allocate(minim%obs(minim%ny))
      allocate(minim%l0rl0_to_l0(bpar%nl0r(ib),geom%nl0))
      allocate(minim%disth(nam%nc3))
      allocate(minim%distv(geom%nl0,geom%nl0))

      ! Fill minim
      il0sup = 1
      do il1inf=1,minim%nl1
         il1sup = min(il1inf+1,minim%nl1)
         il0inf = il0sup
         il0sup = min(il0inf+minim%dl0,geom%nl0)
         do jl0=il0inf,il0sup
            if (il0inf==il0sup) then
               minim%il1inf(jl0) = il1inf
               minim%rinf(jl0) = 1.0
               minim%il1sup(jl0) = il1sup
               minim%rsup(jl0) = 0.0
            else
               minim%il1inf(jl0) = il1inf
               minim%rinf(jl0) = real(il0sup-jl0,kind_real)/real(il0sup-il0inf,kind_real)
               minim%il1sup(jl0) = il1sup
               minim%rsup(jl0) = real(jl0-il0inf,kind_real)/real(il0sup-il0inf,kind_real)
            end if
         end do
         ivar = 0
         if (lcoef) then
            minim%guess(ivar*minim%nl1+il1inf) = diag_blk%coef_ens(il0inf)
            ivar = ivar+1
         end if
         if (lrh) then
            minim%guess(ivar*minim%nl1+il1inf) = diag_blk%fit_rh(il0inf)
            ivar = ivar+1
         end if
         if (lrv) then
            minim%guess(ivar*minim%nl1+il1inf) = diag_blk%fit_rv(il0inf)
            ivar = ivar+1
         end if
      end do
      ivar = 0
      if (lcoef) then
         minim%binf(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 0.9*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         minim%bsup(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 1.1*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         ivar = ivar+1
      end if
      if (lrh) then
         minim%binf(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 0.5*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         minim%bsup(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 2.0*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         ivar = ivar+1
      end if
      if (lrv) then
         minim%binf(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 0.5*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         minim%bsup(ivar*minim%nl1+1:(ivar+1)*minim%nl1) = 2.0*minim%guess(ivar*minim%nl1+1:(ivar+1)*minim%nl1)
         ivar = ivar+1
      end if
      minim%obs = pack(diag_blk%raw,mask=.true.)
      minim%cost_function = 'fit_diag'
      minim%algo = nam%minim_algo
      minim%nc3 = nam%nc3
      minim%nl0r = bpar%nl0r(ib)
      minim%nl0 = geom%nl0
      minim%l0rl0_to_l0 = bpar%l0rl0b_to_l0(:,:,ib)
      minim%disth = geom%disth
      minim%distv = diag_blk%distv
      minim%lcoef = lcoef
      minim%lrh = lrh
      minim%lrv = lrv

      ! Compute fit
      call minim%compute(mpl,rng)

      ! Apply bounds
      minim%x = max(minim%binf,min(minim%x,minim%bsup))

      ! Interpolate parameters
      do il0=1,geom%nl0
         ivar = 0
         if (lcoef) then
            diag_blk%coef_ens(il0) = minim%rinf(il0)*minim%x(ivar*minim%nl1+minim%il1inf(il0)) &
 & +minim%rsup(il0)*minim%x(ivar*minim%nl1+minim%il1sup(il0))
            ivar = ivar+1
         end if
         if (lrh) then
            diag_blk%fit_rh(il0) = minim%rinf(il0)*minim%x(ivar*minim%nl1+minim%il1inf(il0)) &
 & +minim%rsup(il0)*minim%x(ivar*minim%nl1+minim%il1sup(il0))
            ivar = ivar+1
         end if
         if (lrv) then
            diag_blk%fit_rv(il0) = minim%rinf(il0)*minim%x(ivar*minim%nl1+minim%il1inf(il0)) &
 & +minim%rsup(il0)*minim%x(ivar*minim%nl1+minim%il1sup(il0))
            ivar = ivar+1
         end if
      end do

      ! Release memory
      deallocate(minim%x)
      deallocate(minim%guess)
      deallocate(minim%binf)
      deallocate(minim%bsup)
      deallocate(minim%obs)
      deallocate(minim%l0rl0_to_l0)
      deallocate(minim%disth)
      deallocate(minim%distv)
   end select

   ! Set to missing values if no point available
   do il0=1,geom%nl0
      if (mpl%msv%isall(diag_blk%raw(:,:,il0))) then
         diag_blk%coef_ens(il0) = mpl%msv%valr
         diag_blk%fit_rh(il0) = mpl%msv%valr
         diag_blk%fit_rv(il0) = mpl%msv%valr
      end if
   end do
else
   ! Set to missing values if no point available
   diag_blk%coef_ens = mpl%msv%valr
   diag_blk%fit_rh = mpl%msv%valr
   diag_blk%fit_rv = mpl%msv%valr
end if

! Release memory
deallocate(rawv)
deallocate(distv)
deallocate(fit)
deallocate(fit_pack)
deallocate(obs_pack)

! End associate
end associate

end subroutine diag_blk_fitting

!----------------------------------------------------------------------
! Subroutine: diag_blk_localization
! Purpose: diag_blk localization
!----------------------------------------------------------------------
subroutine diag_blk_localization(diag_blk,mpl,geom,bpar,avg_blk)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block (localization)
type(mpl_type),intent(inout) :: mpl            ! MPI data
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters
type(avg_blk_type),intent(in) :: avg_blk       ! Averaged statistics block

! Local variables
integer :: il0,jl0r,jc3

! Associate
associate(ib=>diag_blk%ib)

!$omp parallel do schedule(static) private(il0,jl0r,jc3) shared(geom,bpar,diag_blk,avg_blk)
do il0=1,geom%nl0
   do jl0r=1,bpar%nl0r(ib)
      do jc3=1,bpar%nc3(ib)
         if (mpl%msv%isnot(avg_blk%m11asysq(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11sq(jc3,jl0r,il0))) then
            ! Compute localization
            diag_blk%raw(jc3,jl0r,il0) = avg_blk%m11asysq(jc3,jl0r,il0)/avg_blk%m11sq(jc3,jl0r,il0)
            diag_blk%valid(jc3,jl0r,il0) = avg_blk%nc1a(jc3,jl0r,il0)
         else
            ! Missing value
            diag_blk%raw(jc3,jl0r,il0) = mpl%msv%valr
            diag_blk%valid(jc3,jl0r,il0) = mpl%msv%valr
         end if
      end do
   end do
end do
!$omp end parallel do

! Hybrid weight
diag_blk%coef_sta = mpl%msv%valr

! End associate
end associate

end subroutine diag_blk_localization

!----------------------------------------------------------------------
! Subroutine: diag_blk_hybridization
! Purpose: diag_blk hybridization
!----------------------------------------------------------------------
subroutine diag_blk_hybridization(diag_blk,mpl,nam,geom,bpar,avg_blk)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk ! Diagnostic block (localization)
type(mpl_type),intent(inout) :: mpl            ! MPI data
type(nam_type),intent(in) :: nam               ! Namelist
type(geom_type),intent(in) :: geom             ! Geometry
type(bpar_type),intent(in) :: bpar             ! Block parameters
type(avg_blk_type),intent(in) :: avg_blk       ! Averaged statistics block

! Local variables
integer :: il0,jl0r,jl0,jc3
real(kind_real) :: wgt,a,bc,d,e,f,num_ens,num_sta,num,den
real(kind_real),allocatable :: coef_ens(:),rh(:),rv(:)

! Associate
associate(ib=>diag_blk%ib)

if (nam%forced_radii) then
   ! Allocation
   allocate(coef_ens(geom%nl0))
   allocate(rh(geom%nl0))
   allocate(rv(geom%nl0))

   ! Initialization
   coef_ens = 1.0
   rh = nam%rh
   rv = nam%rv

   ! Compute forced localization function
   call fit_diag(mpl,nam%nc3,bpar%nl0r(ib),geom%nl0,bpar%l0rl0b_to_l0(:,:,ib),geom%disth,diag_blk%distv, &
 & coef_ens,rh,rv,diag_blk%raw)
   diag_blk%valid = mpl%msv%valr

   ! Compute hybrid weights
   a = 0.0
   bc = 0.0
   d = 0.0
   e = 0.0
   f = 0.0
   do il0=1,geom%nl0
      do jl0r=1,bpar%nl0r(ib)
         jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)
         do jc3=1,bpar%nc3(ib)
            if (mpl%msv%isnot(avg_blk%m11asysq(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11sq(jc3,jl0r,il0)) &
 & .and.mpl%msv%isnot(avg_blk%m11sta(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%stasq(jc3,jl0r,il0))) then
               wgt = geom%disth(jc3)*diag_blk%distv(jl0,il0)/real(bpar%nl0r(ib)+bpar%nc3(ib),kind_real)
               a = a+wgt*diag_blk%raw(jc3,jl0r,il0)**2*avg_blk%m11sq(jc3,jl0r,il0)
               bc = bc+wgt*diag_blk%raw(jc3,jl0r,il0)*avg_blk%m11sta(jc3,jl0r,il0)
               d = d+wgt*avg_blk%stasq(jc3,jl0r,il0)
               e = e+wgt*diag_blk%raw(jc3,jl0r,il0)*avg_blk%m11asysq(jc3,jl0r,il0)
               f = f+wgt*avg_blk%m11sta(jc3,jl0r,il0)
            end if
         end do
      end do
   end do
   num_ens = e*d-bc*f
   num_sta = a*f-e*bc
   den = a*d-bc**2
   if ((num_ens>0.0).and.(num_sta>0.0).and.(den>0.0)) then
      ! Valid numerators and denominator
      diag_blk%coef_ens = num_ens/den
      diag_blk%coef_sta = num_sta/den
   else
      ! Missing values
      diag_blk%coef_ens = mpl%msv%valr
      diag_blk%coef_sta = mpl%msv%valr
   end if

   ! Release memory
   deallocate(coef_ens)
   deallocate(rh)
   deallocate(rv)
else
   ! Compute raw hybridization
   num = 0.0
   den = 0.0
   do il0=1,geom%nl0
      do jl0r=1,bpar%nl0r(ib)
         jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)
         do jc3=1,bpar%nc3(ib)
            if (mpl%msv%isnot(avg_blk%m11asysq(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11sq(jc3,jl0r,il0)) &
 & .and.mpl%msv%isnot(avg_blk%m11sta(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%stasq(jc3,jl0r,il0))) then
               wgt = geom%disth(jc3)*diag_blk%distv(jl0,il0)/real(bpar%nl0r(ib)+bpar%nc3(ib),kind_real)
               num = num+wgt*(1.0-avg_blk%m11asysq(jc3,jl0r,il0)/avg_blk%m11sq(jc3,jl0r,il0))*avg_blk%m11sta(jc3,jl0r,il0)
               den = den+wgt*(avg_blk%stasq(jc3,jl0r,il0)-avg_blk%m11sta(jc3,jl0r,il0)**2/avg_blk%m11sq(jc3,jl0r,il0))
            end if
         end do
      end do
   end do
   if ((num>0.0).and.(den>0.0)) then
      ! Valid numerator and denominator
      diag_blk%coef_sta = num/den

      !$omp parallel do schedule(static) private(il0,jl0r,jc3) shared(geom,bpar,diag_blk)
      do il0=1,geom%nl0
         do jl0r=1,bpar%nl0r(ib)
            do jc3=1,bpar%nc3(ib)
               if (mpl%msv%isnot(avg_blk%m11asysq(jc3,jl0r,il0)).and.mpl%msv%isnot(diag_blk%coef_sta) &
 & .and.mpl%msv%isnot(avg_blk%m11sta(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11sq(jc3,jl0r,il0))) then
                  ! Compute localization
                  diag_blk%raw(jc3,jl0r,il0) = (avg_blk%m11asysq(jc3,jl0r,il0)-diag_blk%coef_sta &
 & *avg_blk%m11sta(jc3,jl0r,il0))/avg_blk%m11sq(jc3,jl0r,il0)
                  diag_blk%valid(jc3,jl0r,il0) = avg_blk%nc1a(jc3,jl0r,il0)

                  ! Lower bound
                  if (diag_blk%raw(jc3,jl0r,il0)<0.0) then
                     diag_blk%raw(jc3,jl0r,il0) = mpl%msv%valr
                     diag_blk%valid(jc3,jl0r,il0) = mpl%msv%valr
                  end if
               else
                  ! Missing value
                  diag_blk%raw(jc3,jl0r,il0) = mpl%msv%valr
                  diag_blk%valid(jc3,jl0r,il0) = mpl%msv%valr
               end if
            end do
         end do
      end do
      !$omp end parallel do
   else
      ! Missing values
      diag_blk%coef_sta = mpl%msv%valr
      diag_blk%raw = mpl%msv%valr
   end if
end if

! End associate
end associate

end subroutine diag_blk_hybridization

!----------------------------------------------------------------------
! Subroutine: diag_blk_dualens
! Purpose: diag_blk dualens
!----------------------------------------------------------------------
subroutine diag_blk_dualens(diag_blk,mpl,geom,bpar,avg_blk,avg_lr_blk,diag_lr_blk)

implicit none

! Passed variables
class(diag_blk_type),intent(inout) :: diag_blk   ! Diagnostic block (localization)
type(mpl_type),intent(inout) :: mpl              ! MPI data
type(geom_type),intent(in) :: geom               ! Geometry
type(bpar_type),intent(in) :: bpar               ! Block parameters
type(avg_blk_type),intent(in) :: avg_blk         ! Averaged statistics block
type(avg_blk_type),intent(in) :: avg_lr_blk      ! LR averaged statistics block
type(diag_blk_type),intent(inout) :: diag_lr_blk ! Diagnostic block (LR localization)

! Local variables
integer :: il0,jl0r,jc3
real(kind_real),allocatable :: num(:),num_lr(:),den(:)

! Associate
associate(ib=>diag_blk%ib)

! Allocation
allocate(num(bpar%nc3(ib)))
allocate(num_lr(bpar%nc3(ib)))
allocate(den(bpar%nc3(ib)))

! Compute raw dual-ensemble hybridization
do il0=1,geom%nl0
   do jl0r=1,bpar%nl0r(ib)
      do jc3=1,bpar%nc3(ib)
         if (mpl%msv%isnot(avg_blk%m11asysq(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11sq(jc3,jl0r,il0)) &
 & .and.mpl%msv%isnot(avg_blk%m11lrm11asy(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11lrm11(jc3,jl0r,il0)) &
 & .and.mpl%msv%isnot(avg_lr_blk%m11sq(jc3,jl0r,il0)).and.mpl%msv%isnot(avg_blk%m11lrm11asy(jc3,jl0r,il0))) then
            num(jc3) = avg_blk%m11asysq(jc3,jl0r,il0)*avg_lr_blk%m11sq(jc3,jl0r,il0) &
 & -avg_blk%m11lrm11asy(jc3,jl0r,il0)*avg_blk%m11lrm11(jc3,jl0r,il0)
            num_lr(jc3) = avg_blk%m11lrm11asy(jc3,jl0r,il0)*avg_blk%m11sq(jc3,jl0r,il0) &
 & -avg_blk%m11asysq(jc3,jl0r,il0)*avg_blk%m11lrm11(jc3,jl0r,il0)
            den(jc3) = avg_blk%m11sq(jc3,jl0r,il0)*avg_lr_blk%m11sq(jc3,jl0r,il0)-avg_blk%m11lrm11(jc3,jl0r,il0)**2
            if ((num(jc3)>0.0).and.(den(jc3)>0.0)) then
               ! Compute localization
               diag_blk%raw(jc3,jl0r,il0) = num(jc3)/den(jc3)
               diag_lr_blk%raw(jc3,jl0r,il0) = num_lr(jc3)/den(jc3)
               diag_blk%valid(jc3,jl0r,il0) = avg_blk%nc1a(jc3,jl0r,il0)
               diag_lr_blk%valid(jc3,jl0r,il0) = avg_blk%nc1a(jc3,jl0r,il0)
            else
               ! Missing value
               diag_blk%raw(jc3,jl0r,il0) = mpl%msv%valr
               diag_lr_blk%raw(jc3,jl0r,il0) = mpl%msv%valr
               diag_blk%valid(jc3,jl0r,il0) = mpl%msv%valr
               diag_lr_blk%valid(jc3,jl0r,il0) = mpl%msv%valr
            end if
         end if
      end do
   end do
end do

! Hybrid weight
diag_blk%coef_sta = mpl%msv%valr

! Release memory
deallocate(num)
deallocate(num_lr)
deallocate(den)

! End associate
end associate

end subroutine diag_blk_dualens

end module type_diag_blk
