!----------------------------------------------------------------------
! Module: tools_const
!> Purpose: usual constants
!> <br>
!> Author: Benjamin Menetrier
!> <br>
!> Licensing: this code is distributed under the CeCILL-C license
!> <br>
!> Copyright © 2017 METEO-FRANCE
!----------------------------------------------------------------------
module tools_const

use tools_display, only: msgerror
use tools_kinds, only: kind_real
use tools_missing, only: msr,isnotmsr
use tools_qsort, only: qsort

implicit none

! Constants
real(kind_real),parameter :: pi=acos(-1.0)    !< Pi
real(kind_real),parameter :: deg2rad=pi/180.0 !< Degree to radian
real(kind_real),parameter :: rad2deg=180.0/pi !< Radian to degree
real(kind_real),parameter :: req=6.371e6      !< Earth radius (m)
real(kind_real),parameter :: reqkm=6.371e3      !< Earth radius (km)
real(kind_real),parameter :: ps=101325.0      !< Reference surface pressure

! Eigendecomposition
real,allocatable :: egvmat(:,:) !< Eigendecomposition matrix

private
public :: pi,deg2rad,rad2deg,req,reqkm,ps,egvmat
public :: eigen_init,lonmod,sphere_dist,reduce_arc,vector_product,vector_triple_product,gc99,median

contains

!----------------------------------------------------------------------
! Subroutine: eigen_init
!> Purpose: initialize eigendecomposition
!----------------------------------------------------------------------
subroutine eigen_init(nc)

implicit none

! Passed variables
integer,intent(in) :: nc !< Matrix size

! Local variables
integer :: ic,jc
real(kind_real),allocatable :: permat(:,:),resmat(:,:)
complex(kind_real),allocatable :: FFT(:,:),FFTinv(:,:)

! Allocation
allocate(egvmat(nc,nc))

if (nc>1) then
   ! Allocation
   allocate(permat(2*(nc-1),nc))
   allocate(resmat(nc,2*(nc-1)))
   allocate(FFT(2*(nc-1),2*(nc-1)))
   allocate(FFTinv(2*(nc-1),2*(nc-1)))

   ! Periodization matrix
   permat = 0.0
   permat(1,1) = 1.0
   do ic=2,nc-1
      permat(ic,ic) = 1.0
      permat(2*nc-ic,ic) = 1.0
   end do
   permat(nc,nc) = 1.0

   ! FFT matrix
   do ic=1,2*(nc-1)
      do jc=1,2*(nc-1)
         FFT(ic,jc) = exp(-2.0*(0.0,1.0)*pi*float((ic-1)*(jc-1))/float(2*(nc-1)))
         FFTinv(ic,jc) = exp(2.0*(0.0,1.0)*pi*float((ic-1)*(jc-1))/float(2*(nc-1)))/float(2*(nc-1))
      end do
   end do

   ! Restriction matrix
   resmat = 0.0
   do ic=1,nc
      resmat(ic,ic) = 1.0
   end do

   ! Eigendecomposition matrix
   egvmat = real(matmul(resmat,matmul(FFT,permat)),kind=kind_real)

   ! Release memory
   deallocate(permat)
   deallocate(resmat)
   deallocate(FFT)
   deallocate(FFTinv)
else
   egvmat = 1.0
end if

end subroutine eigen_init

!----------------------------------------------------------------------
! Function: lonmod
!> Purpose: set longitude between -pi and pi
!----------------------------------------------------------------------
real(kind_real) function lonmod(lon)

implicit none

! Passed variables
real(kind_real),intent(in) :: lon !< Longitude

! Check bounds
lonmod = lon
if (lonmod>pi) then
   lonmod = lonmod-2.0*pi
elseif (lonmod<-pi) then
   lonmod = lonmod+2.0*pi
end if

end function lonmod

!----------------------------------------------------------------------
! Function: sphere_dist
!> Purpose: compute the great-circle distance between two points
!----------------------------------------------------------------------
subroutine sphere_dist(lon_i,lat_i,lon_f,lat_f,dist)

implicit none

! Passed variable
real(kind_real),intent(in) :: lon_i !< Initial point longitude (radian)
real(kind_real),intent(in) :: lat_i !< Initial point latitude (radian)
real(kind_real),intent(in) :: lon_f !< Final point longitude (radian)
real(kind_real),intent(in) :: lat_f !< Final point longilatitudetude (radian)
real(kind_real),intent(out) :: dist !< Great-circle distance

! Check that there is no missing value
if (isnotmsr(lon_i).and.isnotmsr(lat_i).and.isnotmsr(lon_f).and.isnotmsr(lat_f)) then
   ! Great-circle distance using Vincenty formula on the unit sphere
    dist = atan2(sqrt((cos(lat_f)*sin(lon_f-lon_i))**2 &
         & +(cos(lat_i)*sin(lat_f)-sin(lat_i)*cos(lat_f)*cos(lon_f-lon_i))**2), & 
         & sin(lat_i)*sin(lat_f)+cos(lat_i)*cos(lat_f)*cos(lon_f-lon_i))
else
   call msr(dist)
end if

end subroutine sphere_dist

!----------------------------------------------------------------------
! Subroutine: reduce_arc
!> Purpose: reduce arc to a given distance
!----------------------------------------------------------------------
subroutine reduce_arc(lon_i,lat_i,lon_f,lat_f,maxdist,dist)

implicit none

! Passed variables
real(kind_real),intent(in) :: lon_i    !< Initial point longitude
real(kind_real),intent(in) :: lat_i    !< Initial point latitude
real(kind_real),intent(inout) :: lon_f !< Final point longitude
real(kind_real),intent(inout) :: lat_f !< Final point latitude
real(kind_real),intent(in) :: maxdist  !< Maximum distance
real(kind_real),intent(out) :: dist    !< Effective distance

! Local variable
real(kind_real) :: theta

! Compute distance
call sphere_dist(lon_i,lat_i,lon_f,lat_f,dist)

! Check with the maximum distance
if (dist>maxdist) then
   ! Compute bearing
   theta = atan2(sin(lon_f-lon_i)*cos(lat_f),cos(lat_i)*sin(lat_f)-sin(lat_i)*cos(lat_f)*cos(lon_f-lon_i))

   ! Reduce distance
   dist = maxdist

   ! Compute new point
   lat_f = asin(sin(lat_i)*cos(dist)+cos(lat_i)*sin(dist)*cos(theta))
   lon_f = lon_i+atan2(sin(theta)*sin(dist)*cos(lat_i),cos(dist)-sin(lat_i)*sin(lat_f))
end if

end subroutine reduce_arc

!----------------------------------------------------------------------
! Subroutine: vector_product
!> Purpose: compute normalized vector product
!----------------------------------------------------------------------
subroutine vector_product(v1,v2,vp)

implicit none

! Passed variables
real(kind_real),intent(in) :: v1(3)  !< First vector
real(kind_real),intent(in) :: v2(3)  !< Second vector
real(kind_real),intent(out) :: vp(3) !< Vector product

! Local variable
real(kind_real) :: r

! Vector product
vp(1) = v1(2)*v2(3)-v1(3)*v2(2)
vp(2) = v1(3)*v2(1)-v1(1)*v2(3)
vp(3) = v1(1)*v2(2)-v1(2)*v2(1)

! Normalization
r = sqrt(sum(vp**2))
if (r>0.0) vp = vp/r

end subroutine vector_product

!----------------------------------------------------------------------
! Subroutine: vector_triple_product
!> Purpose: compute vector triple product
!----------------------------------------------------------------------
subroutine vector_triple_product(v1,v2,v3,p)

implicit none

! Passed variables
real(kind_real),intent(in) :: v1(3) !< First vector
real(kind_real),intent(in) :: v2(3) !< Second vector
real(kind_real),intent(in) :: v3(3) !< Third vector
real(kind_real),intent(out) :: p    !< Triple product

! Local variable
real(kind_real) :: vp(3)

! Vector product
vp(1) = v1(2)*v2(3)-v1(3)*v2(2)
vp(2) = v1(3)*v2(1)-v1(1)*v2(3)
vp(3) = v1(1)*v2(2)-v1(2)*v2(1)

! Scalar product
p = sum(vp*v3)

end subroutine vector_triple_product


!----------------------------------------------------------------------
! Function: gc99
!> Purpose: Gaspari and Cohn (1999) function, with the support radius as a parameter
!----------------------------------------------------------------------
function gc99(distnorm)

! Passed variables
real(kind_real),intent(in) :: distnorm

! Returned variable
real(kind_real) :: gc99

! Distance check bound
if (distnorm<0.0) call msgerror('negative normalized distance')

if (distnorm<0.5) then
   gc99 = 1.0-8.0*distnorm**5+8.0*distnorm**4+5.0*distnorm**3-20.0/3.0*distnorm**2
else if (distnorm<1.0) then
   gc99 = 8.0/3.0*distnorm**5-8.0*distnorm**4+5.0*distnorm**3+20.0/3.0*distnorm**2-10.0*distnorm+4.0-1.0/(3.0*distnorm)
else
   gc99 = 0.0
end if

return

end function gc99

!----------------------------------------------------------------------
! Function: median
!> Purpose: compute median of a list
!----------------------------------------------------------------------
function median(n,list)

implicit none

! Passed variables
integer,intent(in) :: n    !< Size of the list
real(kind_real),intent(in) :: list(n) !< List

! Returned variable
real(kind_real) :: median

! Local variables
integer :: order(n)
real(kind_real) :: list_copy(n)

! Copy list
list_copy = list

! Order array
call qsort(n,list_copy,order)

! Get median
call msr(median)
if (mod(n,2)==0) then
   ! Even number of values
   median = 0.5*(list_copy(n/2)+list_copy(n/2+1))
else
   ! Odd number of values
   median = list_copy((n+1)/2)
end if

return

end function median

end module tools_const
