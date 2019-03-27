!----------------------------------------------------------------------
! Subroutine: model_gem_coord
! Purpose: get GEM coordinates
!----------------------------------------------------------------------
subroutine model_gem_coord(model,mpl,nam)

implicit none

! Passed variables
class(model_type),intent(inout) :: model ! Model
type(mpl_type),intent(inout) :: mpl      ! MPI data
type(nam_type),intent(in) :: nam         ! Namelist

! Local variables
integer :: img,il0,ilon,ilat
integer :: ncid,nlon_id,nlat_id,nlev_id,lon_id,lat_id,a_id,b_id
real(kind=8),allocatable :: lon(:),lat(:),a(:),b(:)
character(len=1024),parameter :: subr = 'model_gem_coord'

! Open file and get dimensions
call mpl%ncerr(subr,nf90_open(trim(nam%datadir)//'/grid.nc',nf90_share,ncid))
call mpl%ncerr(subr,nf90_inq_dimid(ncid,'lon',nlon_id))
call mpl%ncerr(subr,nf90_inq_dimid(ncid,'lat',nlat_id))
call mpl%ncerr(subr,nf90_inquire_dimension(ncid,nlon_id,len=model%nlon))
call mpl%ncerr(subr,nf90_inquire_dimension(ncid,nlat_id,len=model%nlat))
model%nmg = model%nlon*model%nlat
call mpl%ncerr(subr,nf90_inq_dimid(ncid,'lev',nlev_id))
call mpl%ncerr(subr,nf90_inquire_dimension(ncid,nlev_id,len=model%nlev))

! Allocation
call model%alloc
allocate(lon(model%nlon))
allocate(lat(model%nlat))
allocate(a(model%nlev))
allocate(b(model%nlev))

! Read data and close file
call mpl%ncerr(subr,nf90_inq_varid(ncid,'lon',lon_id))
call mpl%ncerr(subr,nf90_inq_varid(ncid,'lat',lat_id))
call mpl%ncerr(subr,nf90_inq_varid(ncid,'ap',a_id))
call mpl%ncerr(subr,nf90_inq_varid(ncid,'b',b_id))
call mpl%ncerr(subr,nf90_get_var(ncid,lon_id,lon))
call mpl%ncerr(subr,nf90_get_var(ncid,lat_id,lat))
call mpl%ncerr(subr,nf90_get_var(ncid,a_id,a))
call mpl%ncerr(subr,nf90_get_var(ncid,b_id,b))
call mpl%ncerr(subr,nf90_close(ncid))

! Convert to radian
lon = lon*deg2rad
lat = lat*deg2rad

! Model grid
img = 0
do ilon=1,model%nlon
   do ilat=1,model%nlat
      img = img+1
      model%mg_to_lon(img) = ilon
      model%mg_to_lat(img) = ilat
      model%lon(img) = lon(ilon)
      model%lat(img) = lat(ilat)
   end do
end do
model%area = 4.0*pi/real(model%nmg,kind_real)
model%mask = .true.

! Vertical unit
do img=1,model%nmg
   if (nam%logpres) then
      model%vunit(img,1:nam%nl) = log(a(nam%levs(1:nam%nl))+b(nam%levs(1:nam%nl))*ps)
      if (model%nl0>nam%nl) model%vunit(img,model%nl0) = log(ps)
   else
      model%vunit(img,:) = real(nam%levs(1:model%nl0),kind_real)
   end if
end do

! Release memory
deallocate(lon)
deallocate(lat)
deallocate(a)
deallocate(b)

end subroutine model_gem_coord

!----------------------------------------------------------------------
! Subroutine: model_gem_read
! Purpose: read GEM field
!----------------------------------------------------------------------
subroutine model_gem_read(model,mpl,nam,filename,its,fld)

implicit none

! Passed variables
class(model_type),intent(inout) :: model                        ! Model
type(mpl_type),intent(inout) :: mpl                             ! MPI data
type(nam_type),intent(in) :: nam                                ! Namelist
character(len=*),intent(in) :: filename                         ! File name
integer,intent(in) :: its                                       ! Timeslot index
real(kind_real),intent(out) :: fld(model%nmga,model%nl0,nam%nv) ! Field

! Local variables
integer :: iv,il0,xt,img,ilon,ilat
integer :: ncid,fld_id
integer,allocatable :: fld_tmp_int(:,:)
real(kind_real) :: add_offset,scale_factor
real(kind_real) :: fld_mg(model%nmg,model%nl0)
real(kind_real),allocatable :: fld_tmp(:,:,:)
character(len=1024),parameter :: subr = 'model_gem_read'

if (mpl%main) then
   ! Allocation
   allocate(fld_tmp_int(model%nlon,model%nlat))
   allocate(fld_tmp(model%nlon,model%nlat,model%nl0))

   ! Open file
   call mpl%ncerr(subr,nf90_open(trim(nam%datadir)//'/'//trim(filename),nf90_nowrite,ncid))
end if

do iv=1,nam%nv
   if (mpl%main) then
      ! 3d variable

      ! Get variable id
      call mpl%ncerr(subr,nf90_inq_varid(ncid,trim(nam%varname(iv)),fld_id))

      ! Check variable type and read data
      call mpl%ncerr(subr,nf90_inquire_variable(ncid,fld_id,xtype=xt))
      select case (xt)
      case (nf90_short)
         call mpl%ncerr(subr,nf90_get_att(ncid,fld_id,'add_offset',add_offset))
         call mpl%ncerr(subr,nf90_get_att(ncid,fld_id,'scale_factor',scale_factor))
         do il0=1,nam%nl
            call mpl%ncerr(subr,nf90_get_var(ncid,fld_id,fld_tmp_int,(/1,1,nam%levs(il0)/),(/model%nlon,model%nlat,1/)))
            fld_tmp(:,:,il0) = add_offset+scale_factor*real(fld_tmp_int,kind_real)
         end do
      case (nf90_double)
         do il0=1,nam%nl
            call mpl%ncerr(subr,nf90_get_var(ncid,fld_id,fld_tmp(:,:,il0),(/1,1,nam%levs(il0)/),(/model%nlon,model%nlat,1/)))
         end do
      case default
         call mpl%abort(subr,'wrong variable type')
      end select

      if (trim(nam%addvar2d(iv))/='') then
         ! 2d variable

         ! Get id
         call mpl%ncerr(subr,nf90_inq_varid(ncid,trim(nam%addvar2d(iv)),fld_id))

         ! Check variable type and read data
         call mpl%ncerr(subr,nf90_inquire_variable(ncid,fld_id,xtype=xt))
         select case (xt)
         case (nf90_short)
            call mpl%ncerr(subr,nf90_get_att(ncid,fld_id,'add_offset',add_offset))
            call mpl%ncerr(subr,nf90_get_att(ncid,fld_id,'scale_factor',scale_factor))
            call mpl%ncerr(subr,nf90_get_var(ncid,fld_id,fld_tmp_int))
            fld_tmp(:,:,model%nl0) = add_offset+scale_factor*real(fld_tmp_int,kind_real)
         case (nf90_double)
            call mpl%ncerr(subr,nf90_get_var(ncid,fld_id,fld_tmp(:,:,model%nl0)))
         case default
            call mpl%abort(subr,'wrong variable type')
         end select
      end if

      ! Pack
      do il0=1,model%nl0
         do img=1,model%nmg
            ilon = model%mg_to_lon(img)
            ilat = model%mg_to_lat(img)
            fld_mg(img,il0) = fld_tmp(ilon,ilat,il0)
         end do
      end do
   end if
   call mpl%glb_to_loc(model%nl0,model%nmg,model%mg_to_proc,model%mg_to_mga,fld_mg,model%nmga,fld(:,:,iv))
end do

if (mpl%main) then
   ! Close file
   call mpl%ncerr(subr,nf90_close(ncid))

   ! Release memory
   deallocate(fld_tmp_int)
   deallocate(fld_tmp)
end if

end subroutine model_gem_read