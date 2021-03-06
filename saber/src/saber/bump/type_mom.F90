!----------------------------------------------------------------------
! Module: type_mom
! Purpose: moments derived type
! Author: Benjamin Menetrier
! Licensing: this code is distributed under the CeCILL-C license
! Copyright © 2015-... UCAR, CERFACS, METEO-FRANCE and IRIT
!----------------------------------------------------------------------
module type_mom

!$ use omp_lib
use netcdf
use tools_kinds, only: kind_real,nc_kind_real
use tools_repro, only: eq
use type_bpar, only: bpar_type
use type_com, only: com_type
use type_ens, only: ens_type
use type_geom, only: geom_type
use type_linop, only: linop_type
use type_mom_blk, only: mom_blk_type
use type_mpl, only: mpl_type
use type_nam, only: nam_type
use type_samp, only: samp_type

implicit none

! Moments derived type
type mom_type
   integer :: ne                            ! Ensemble size
   integer :: nsub                          ! Number of sub-ensembles
   character(len=1024) :: prefix            ! Prefix
   type(mom_blk_type),allocatable :: blk(:) ! Moments blocks
contains
   procedure :: alloc => mom_alloc
   procedure :: init => mom_init
   procedure :: dealloc => mom_dealloc
   procedure :: read => mom_read
   procedure :: write => mom_write
   procedure :: compute => mom_compute
end type mom_type

private
public :: mom_type

contains

!----------------------------------------------------------------------
! Subroutine: mom_alloc
! Purpose: allocation
!----------------------------------------------------------------------
subroutine mom_alloc(mom,geom,bpar,samp,ne,nsub,prefix)

implicit none

! Passed variables
class(mom_type),intent(inout) :: mom  ! Moments
type(geom_type),intent(in) :: geom    ! Geometry
type(bpar_type),intent(in) :: bpar    ! Block parameters
type(samp_type),intent(in) :: samp    ! Sampling
integer,intent(in) :: ne              ! Ensemble size
integer,intent(in) :: nsub            ! Number of sub-ensembles
character(len=*),intent(in) :: prefix ! Prefix

! Local variables
integer :: ib

! Set attributes
mom%ne = ne
mom%nsub = nsub
mom%prefix = prefix

! Allocation
allocate(mom%blk(bpar%nb))
do ib=1,bpar%nb
   mom%blk(ib)%ib = ib
   if (bpar%diag_block(ib)) call mom%blk(ib)%alloc(samp%nc1a,geom,bpar,ne,nsub)
end do

end subroutine mom_alloc

!----------------------------------------------------------------------
! Subroutine: mom_init
! Purpose: initialization
!----------------------------------------------------------------------
subroutine mom_init(mom,bpar)

implicit none

! Passed variables
class(mom_type),intent(inout) :: mom ! Moments
type(bpar_type),intent(in) :: bpar   ! Block parameters

! Local variables
integer :: ib

! Initialization
do ib=1,bpar%nb
   if (bpar%diag_block(ib)) then
      mom%blk(ib)%m2_1 = 0.0
      mom%blk(ib)%m2_2 = 0.0
      mom%blk(ib)%m11 = 0.0
      mom%blk(ib)%m22 = 0.0
   end if
end do

end subroutine mom_init

!----------------------------------------------------------------------
! Subroutine: mom_dealloc
! Purpose: release memory
!----------------------------------------------------------------------
subroutine mom_dealloc(mom)

implicit none

! Passed variables
class(mom_type),intent(inout) :: mom ! Moments

! Local variables
integer :: ib

! Release memory
if (allocated(mom%blk)) then
   do ib=1,size(mom%blk)
      call mom%blk(ib)%dealloc
   end do
   deallocate(mom%blk)
end if

end subroutine mom_dealloc

!----------------------------------------------------------------------
! Subroutine: mom_read
! Purpose: read
!----------------------------------------------------------------------
subroutine mom_read(mom,mpl,nam,geom,bpar,samp,ens,prefix)

implicit none

! Passed variables
class(mom_type),intent(inout) :: mom  ! Moments
type(mpl_type),intent(inout) :: mpl   ! MPI data
type(nam_type),intent(in) :: nam      ! Namelist
type(geom_type),intent(in) :: geom    ! Geometry
type(bpar_type),intent(in) :: bpar    ! Block parameters
type(samp_type),intent(in) :: samp    ! Sampling
type(ens_type), intent(in) :: ens     ! Ensemble
character(len=*),intent(in) :: prefix ! Prefix

! Local variables
integer :: ib,isub,grid_hash
integer :: ncid,subgrpid,grpid,m2_1_id,m2_2_id,m11_id,m22_id
character(len=1024) :: filename,grpname,subname
character(len=1024),parameter :: subr = 'mom_read'

! Allocation
call mom%alloc(geom,bpar,samp,ens%ne,ens%nsub,prefix)

! Initialization
call mom%init(bpar)

! Open file
write(filename,'(a,a,i6.6,a,i6.6)') trim(nam%prefix),'_mom_',mpl%nproc,'-',mpl%myproc
call mpl%ncerr(subr,nf90_open(trim(nam%datadir)//'/'//trim(filename)//'.nc',nf90_nowrite,ncid))

! Check grid hash
call mpl%ncerr(subr,nf90_get_att(ncid,nf90_global,'grid_hash',grid_hash))
if (grid_hash/=geom%grid_hash) call mpl%abort(subr,'wrong grid hash')

! Check dimensions
call mpl%nc_dim_check(subr,ncid,'nc1a',samp%nc1a)
call mpl%nc_dim_check(subr,ncid,'nl0',geom%nl0)

do ib=1,bpar%nb
   if (bpar%diag_block(ib)) then
      ! Get group
      call nam%io_key_value(bpar%blockname(ib),grpname)
      call mpl%ncerr(subr,nf90_inq_grp_ncid(ncid,grpname,grpid))

      ! Check dimensions
      call mpl%nc_dim_check(subr,grpid,'nc3',bpar%nc3(ib))
      call mpl%nc_dim_check(subr,grpid,'nl0r',bpar%nl0r(ib))

      do isub=1,mom%blk(ib)%nsub
         ! Get subgroup
         write(subname,'(a,i6.6)') 'sub_',isub
         call mpl%ncerr(subr,nf90_inq_grp_ncid(grpid,subname,subgrpid))

         ! Get variables
         call mpl%ncerr(subr,nf90_inq_varid(subgrpid,'m2_1',m2_1_id))
         call mpl%ncerr(subr,nf90_inq_varid(subgrpid,'m2_2',m2_2_id))
         call mpl%ncerr(subr,nf90_inq_varid(subgrpid,'m11',m11_id))
         call mpl%ncerr(subr,nf90_inq_varid(subgrpid,'m22',m22_id))

         ! Read data
         call mpl%ncerr(subr,nf90_get_var(subgrpid,m2_1_id,mom%blk(ib)%m2_1(:,:,isub)))
         call mpl%ncerr(subr,nf90_get_var(subgrpid,m2_2_id,mom%blk(ib)%m2_2(:,:,:,isub)))
         call mpl%ncerr(subr,nf90_get_var(subgrpid,m11_id,mom%blk(ib)%m11(:,:,:,:,isub)))
         call mpl%ncerr(subr,nf90_get_var(subgrpid,m22_id,mom%blk(ib)%m22(:,:,:,:,isub)))
      end do
   end if
end do

! Close file
call mpl%ncerr(subr,nf90_close(ncid))

end subroutine mom_read

!----------------------------------------------------------------------
! Subroutine: mom_write
! Purpose: write
!----------------------------------------------------------------------
subroutine mom_write(mom,mpl,nam,geom,bpar,samp)

implicit none

! Passed variables
class(mom_type),intent(in) :: mom   ! Moments
type(mpl_type),intent(inout) :: mpl ! MPI data
type(nam_type),intent(in) :: nam    ! Namelist
type(geom_type),intent(in) :: geom  ! Geometry
type(bpar_type),intent(in) :: bpar  ! Block parameters
type(samp_type),intent(in) :: samp  ! Sampling

! Local variables
integer :: ib,isub
integer :: ncid,grpid,subgrpid,nc1a_id,nc3_id,nl0r_id,nl0_id,m2_1_id,m2_2_id,m11_id,m22_id
character(len=1024) :: filename,grpname,subname
character(len=1024),parameter :: subr = 'mom_write'

! Define file
write(filename,'(a,a,i6.6,a,i6.6)') trim(nam%prefix),'_mom_',mpl%nproc,'-',mpl%myproc
ncid = mpl%nc_file_create_or_open(subr,trim(nam%datadir)//'/'//trim(filename)//'.nc')

! Write grid hash
call mpl%ncerr(subr,nf90_put_att(ncid,nf90_global,'grid_hash',geom%grid_hash))

! Write namelist parameters
call nam%write(mpl,ncid)

! Define dimensions
nc1a_id = mpl%nc_dim_define_or_get(subr,ncid,'nc1a',samp%nc1a)
nl0_id = mpl%nc_dim_define_or_get(subr,ncid,'nl0',geom%nl0)

do ib=1,bpar%nb
   if (bpar%diag_block(ib)) then
      ! Define group
      call nam%io_key_value(bpar%blockname(ib),grpname)
      grpid = mpl%nc_group_define_or_get(subr,ncid,grpname)

      ! Define dimensions
      nc3_id = mpl%nc_dim_define_or_get(subr,grpid,'nc3',bpar%nc3(ib))
      nl0r_id = mpl%nc_dim_define_or_get(subr,grpid,'nl0r',bpar%nl0r(ib))

      do isub=1,mom%blk(ib)%nsub
         ! Define subgroup
         write(subname,'(a,i6.6)') 'sub_',isub
         subgrpid = mpl%nc_group_define_or_get(subr,grpid,subname)

         ! Define variables
         m2_1_id = mpl%nc_var_define_or_get(subr,subgrpid,'m2_1',nc_kind_real,(/nc1a_id,nl0_id/))
         m2_2_id = mpl%nc_var_define_or_get(subr,subgrpid,'m2_2',nc_kind_real,(/nc1a_id,nc3_id,nl0_id/))
         m11_id = mpl%nc_var_define_or_get(subr,subgrpid,'m11',nc_kind_real,(/nc1a_id,nc3_id,nl0r_id,nl0_id/))
         m22_id = mpl%nc_var_define_or_get(subr,subgrpid,'m22',nc_kind_real,(/nc1a_id,nc3_id,nl0r_id,nl0_id/))

         ! Write variables
         call mpl%ncerr(subr,nf90_put_var(subgrpid,m2_1_id,mom%blk(ib)%m2_1(:,:,isub)))
         call mpl%ncerr(subr,nf90_put_var(subgrpid,m2_2_id,mom%blk(ib)%m2_2(:,:,:,isub)))
         call mpl%ncerr(subr,nf90_put_var(subgrpid,m11_id,mom%blk(ib)%m11(:,:,:,:,isub)))
         call mpl%ncerr(subr,nf90_put_var(subgrpid,m22_id,mom%blk(ib)%m22(:,:,:,:,isub)))
      end do
   end if
end do

! Close file
call mpl%ncerr(subr,nf90_close(ncid))

end subroutine mom_write

!----------------------------------------------------------------------
! Subroutine: mom_compute
! Purpose: compute centered moments (iterative formulae)
!----------------------------------------------------------------------
subroutine mom_compute(mom,mpl,nam,geom,bpar,samp,ens,prefix)

implicit none

! Passed variables
class(mom_type),intent(inout) :: mom  ! Moments
type(mpl_type),intent(inout) :: mpl   ! MPI data
type(nam_type),intent(in) :: nam      ! Namelist
type(geom_type),intent(in) :: geom    ! Geometry
type(bpar_type),intent(in) :: bpar    ! Block parameters
type(samp_type),intent(in) :: samp    ! Sampling
type(ens_type), intent(in) :: ens     ! Ensemble
character(len=*),intent(in) :: prefix ! Prefix

! Local variables
integer :: ie,ie_sub,ic0c,jc0c,jl0r,jl0,il0,isub,jc3,ic1a,ib,jv,iv,jts,its
real(kind_real) :: fld_c0a(geom%nc0a,geom%nl0,nam%nv)
real(kind_real),allocatable :: fld_ext(:,:,:),fld_1(:,:),fld_2(:,:,:)
logical,allocatable :: mask_unpack(:,:)

! Allocation
call mom%alloc(geom,bpar,samp,ens%ne,ens%nsub,prefix)

! Initialization
call mom%init(bpar)

! Loop on sub-ensembles
do isub=1,ens%nsub
   if (ens%nsub==1) then
      write(mpl%info,'(a10,a)') '','Full ensemble, member:'
      call mpl%flush(.false.)
   else
      write(mpl%info,'(a10,a,i6,a)') '','Sub-ensemble ',isub,', member:'
      call mpl%flush(.false.)
   end if

   ! Compute centered moments
   do ie_sub=1,ens%ne/ens%nsub
      write(mpl%info,'(i6)') ie_sub
      call mpl%flush(.false.)

      ! Full ensemble index
      ie = ie_sub+(isub-1)*ens%ne/ens%nsub

      ! Allocation
      allocate(fld_ext(samp%nc0c,geom%nl0,nam%nv))
      allocate(mask_unpack(samp%nc0c,geom%nl0))
      mask_unpack = .true.

      ! Get perturbation on subset Sc0
      call ens%get_c0(mpl,nam,geom,'pert',ie,fld_c0a)

      do ib=1,bpar%nb
         ! Indices
         iv = bpar%b_to_v1(ib)
         jv = bpar%b_to_v2(ib)

         ! Halo extension
         if (iv==jv) call samp%com_AC%ext(mpl,geom%nl0,fld_c0a(:,:,iv),fld_ext(:,:,iv))
      end do

      do ib=1,bpar%nb
         if (bpar%diag_block(ib)) then
            ! Allocation
            allocate(fld_1(samp%nc1a,geom%nl0))
            allocate(fld_2(samp%nc1a,bpar%nc3(ib),geom%nl0))

            ! Initialization
            iv = bpar%b_to_v1(ib)
            jv = bpar%b_to_v2(ib)

            ! Copy valid field points
            fld_1 = mpl%msv%valr
            fld_2 = mpl%msv%valr
            !$omp parallel do schedule(static) private(il0,ic1a,jc3,ic0c,jc0c)
            do il0=1,geom%nl0
               do ic1a=1,samp%nc1a
                  if (samp%smask_c1a(ic1a,il0)) then
                     ! Indices
                     ic0c = samp%c1a_to_c0c(ic1a)

                     ! Copy field 1
                     fld_1(ic1a,il0) = fld_ext(ic0c,il0,iv)

                     do jc3=1,bpar%nc3(ib)
                        if (samp%smask_c1ac3(ic1a,jc3,il0)) then
                           ! Indices
                           jc0c = samp%c1ac3_to_c0c(ic1a,jc3)

                           ! Copy field 2
                           fld_2(ic1a,jc3,il0) = fld_ext(jc0c,il0,jv)
                        end if
                     end do
                  end if
               end do
            end do
            !$omp end parallel do

            !$omp parallel do schedule(static) private(il0,jl0r,jl0,jc3)
            do il0=1,geom%nl0
               do jl0r=1,bpar%nl0r(ib)
                  jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)

                  do jc3=1,bpar%nc3(ib)
                     ! Fourth-order moment
                     mom%blk(ib)%m22(:,jc3,jl0r,il0,isub) = mom%blk(ib)%m22(:,jc3,jl0r,il0,isub)+(fld_1(:,il0)*fld_2(:,jc3,jl0))**2

                     ! Covariance
                     mom%blk(ib)%m11(:,jc3,jl0r,il0,isub) = mom%blk(ib)%m11(:,jc3,jl0r,il0,isub)+fld_1(:,il0)*fld_2(:,jc3,jl0)
                  end do
               end do
            end do
            !$omp end parallel do

            ! Variances
            mom%blk(ib)%m2_1(:,:,isub) = mom%blk(ib)%m2_1(:,:,isub)+fld_1**2
            mom%blk(ib)%m2_2(:,:,:,isub) = mom%blk(ib)%m2_2(:,:,:,isub)+fld_2**2

            ! Release memory
            deallocate(fld_1)
            deallocate(fld_2)
         end if
      end do

      ! Release memory
      deallocate(fld_ext)
      deallocate(mask_unpack)
   end do
   write(mpl%info,'(a)') ''
   call mpl%flush
end do

! Normalize moments or set missing values
do ib=1,bpar%nb
   if (bpar%diag_block(ib)) then
      !$omp parallel do schedule(static) private(il0,jc3,ic1a,jl0r,jl0)
      do il0=1,geom%nl0
         do ic1a=1,samp%nc1a
            if (samp%smask_c1a(ic1a,il0)) then
               mom%blk(ib)%m2_1(ic1a,il0,:) = mom%blk(ib)%m2_1(ic1a,il0,:)/real(mom%ne/mom%nsub-1,kind_real)
            else
               mom%blk(ib)%m2_1(ic1a,il0,:) = mpl%msv%valr
            end if
         end do
         do jc3=1,bpar%nc3(ib)
            do ic1a=1,samp%nc1a
               if (samp%smask_c1ac3(ic1a,jc3,il0)) then
                  mom%blk(ib)%m2_2(ic1a,jc3,il0,:) = mom%blk(ib)%m2_2(ic1a,jc3,il0,:)/real(mom%ne/mom%nsub-1,kind_real)
               else
                  mom%blk(ib)%m2_2(ic1a,jc3,il0,:) = mpl%msv%valr
               end if
               do jl0r=1,bpar%nl0r(ib)
                  jl0 = bpar%l0rl0b_to_l0(jl0r,il0,ib)
                  if (samp%smask_c1a(ic1a,il0).and.samp%smask_c1ac3(ic1a,jc3,jl0)) then
                     mom%blk(ib)%m11(ic1a,jc3,jl0r,il0,:) = mom%blk(ib)%m11(ic1a,jc3,jl0r,il0,:)/real(mom%ne/mom%nsub-1,kind_real)
                     mom%blk(ib)%m22(ic1a,jc3,jl0r,il0,:) = mom%blk(ib)%m22(ic1a,jc3,jl0r,il0,:)/real(mom%ne/mom%nsub,kind_real)
                  else
                     mom%blk(ib)%m11(ic1a,jc3,jl0r,il0,:) = mpl%msv%valr
                     mom%blk(ib)%m22(ic1a,jc3,jl0r,il0,:) = mpl%msv%valr
                  end if
               end do
            end do
         end do
      end do
      !$omp end parallel do
   end if
end do

! Write sample moments
if (nam%write_mom) then
   write(mpl%info,'(a10,a)') '','Write sample moments'
   call mpl%flush
   call mom%write(mpl,nam,geom,bpar,samp)
end if

end subroutine mom_compute

end module type_mom
