!----------------------------------------------------------------------
! Module: module_hybridization.f90
!> Purpose: hybridization routines
!> <br>
!> Author: Benjamin Menetrier
!> <br>
!> Licensing: this code is distributed under the CeCILL-B license
!> <br>
!> Copyright © 2015 UCAR, CERFACS and METEO-FRANCE
!----------------------------------------------------------------------
module module_hybridization

use module_fit, only: compute_fit
use tools_display, only: msgwarning
use tools_kinds, only: kind_real
use tools_fit, only: ver_smooth
use tools_missing, only: msr,isnotmsr,isallnotmsr
use type_avg, only: avgtype
use type_curve, only: curvetype,curve_normalization
use type_hdata, only: hdatatype
implicit none

private
public :: compute_hybridization

contains

!----------------------------------------------------------------------
! Subroutine: compute_hybridization
!> Purpose: compute static hybridization
!----------------------------------------------------------------------
subroutine compute_hybridization(hdata,avg,lfit,loc_hyb)

implicit none

! Passed variables
type(hdatatype),intent(in) :: hdata               !< Sampling data
type(avgtype),intent(in) :: avg                   !< Averaged statistics
logical,intent(in) :: lfit
type(curvetype),intent(inout) :: loc_hyb !< Adapted localizations

! Local variables
integer :: il0,jl0,ic
real(kind_real) :: num,den

! Associate
associate(nam=>hdata%nam,geom=>hdata%geom)

! Compute raw hybridization
num = 0.0
den = 0.0
do jl0=1,geom%nl0
   do il0=1,geom%nl0
      do ic=1,nam%nc
         if (isnotmsr(avg%m11asysq(ic,il0,jl0)).and.isnotmsr(avg%m11sq(ic,il0,jl0)) &
       & .and.isnotmsr(avg%m11sta(ic,il0,jl0)).and.isnotmsr(avg%stasq(ic,il0,jl0))) then
            num = num+nam%disth(ic)*(1.0-avg%m11asysq(ic,il0,jl0)/avg%m11sq(ic,il0,jl0))*avg%m11sta(ic,il0,jl0)
            den = den+nam%disth(ic)*(avg%stasq(ic,il0,jl0)-avg%m11sta(ic,il0,jl0)**2/avg%m11sq(ic,il0,jl0))
         end if
      end do
   end do
end do
if ((num>0.0).and.(den>0.0)) loc_hyb%raw_coef_sta = num/den
do jl0=1,geom%nl0
   do il0=1,geom%nl0
      do ic=1,nam%nc
         if (isnotmsr(avg%m11asysq(ic,il0,jl0)).and.isnotmsr(loc_hyb%raw_coef_sta) &
       & .and.isnotmsr(avg%m11sta(ic,il0,jl0)).and.isnotmsr(avg%stasq(ic,il0,jl0)) &
       & .and.isnotmsr(avg%m11sq(ic,il0,jl0))) then
            ! Compute localization
            loc_hyb%raw(ic,il0,jl0) = (avg%m11asysq(ic,il0,jl0)-loc_hyb%raw_coef_sta &
                                    & *avg%m11sta(ic,il0,jl0))/avg%m11sq(ic,il0,jl0)
  
            ! Lower bound
            if (loc_hyb%raw(ic,il0,jl0)<0.0) call msr(loc_hyb%raw(ic,il0,jl0))
         end if
      end do
   end do
end do

! Compute hybridization fits
if (lfit) then
   ! Compute fit weight
   if (nam%fit_wgt) loc_hyb%fit_wgt = abs(avg%cor)

   ! Compute initial fit
   call compute_fit(hdata%nam,hdata%geom,loc_hyb)
end if

! Normalize hybridization
call curve_normalization(hdata,loc_hyb)

! End associate
end associate

end subroutine compute_hybridization

end module module_hybridization