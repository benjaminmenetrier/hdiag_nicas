!----------------------------------------------------------------------
! Module: module_localization.f90
!> Purpose: localization routines
!> <br>
!> Author: Benjamin Menetrier
!> <br>
!> Licensing: this code is distributed under the CeCILL-B license
!> <br>
!> Copyright © 2015 UCAR, CERFACS and METEO-FRANCE
!----------------------------------------------------------------------
module module_localization

use module_fit, only: compute_fit
use tools_display, only: msgwarning,msgerror
use tools_fit, only: ver_smooth
use tools_kinds, only: kind_real
use tools_missing, only: msr,isnotmsr,isallnotmsr
use type_avg, only: avgtype
use type_curve, only: curvetype,curve_normalization
use type_hdata, only: hdatatype
implicit none

private
public :: compute_localization

contains

!----------------------------------------------------------------------
! Subroutine: compute_localization
!> Purpose: compute localization
!----------------------------------------------------------------------
subroutine compute_localization(hdata,avg,loc)

implicit none

! Passed variables
type(hdatatype),intent(in) :: hdata           !< Sampling data
type(avgtype),intent(in) :: avg               !< Averaged statistics
type(curvetype),intent(inout) :: loc(hdata%nam%nvp) !< Localizations

! Local variables
integer :: iv,il0,jl0,ic

! Associate
associate(nam=>hdata%nam,geom=>hdata%geom)

! Compute raw localization
do iv=1,nam%nvp
   do jl0=1,geom%nl0
      do il0=1,geom%nl0
         do ic=1,nam%nc
            if (isnotmsr(avg%m11asysq(ic,il0,jl0,iv)).and.isnotmsr(avg%m11sq(ic,il0,jl0,iv))) &
          & loc(iv)%raw(ic,il0,jl0) = avg%m11asysq(ic,il0,jl0,iv)/avg%m11sq(ic,il0,jl0,iv)
         end do
      end do
   end do
end do

! Compute localization fits
if (trim(nam%fit_type)/='none') then
   ! Compute fit weight
   if (nam%fit_wgt) then
      do iv=1,nam%nvp
         loc(iv)%fit_wgt = abs(avg%cor(:,:,:,iv))
      end do
   end if

   ! Compute initial fit
   call compute_fit(hdata%nam,hdata%geom,loc)
end if

! Normalize localization
call curve_normalization(hdata,loc)

! End associate
end associate

end subroutine compute_localization

end module module_localization
