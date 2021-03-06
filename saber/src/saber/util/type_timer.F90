!----------------------------------------------------------------------
! Module: type_timer
! Purpose: timer data derived type
! Author: Benjamin Menetrier
! Licensing: this code is distributed under the CeCILL-C license
! Copyright © 2015-... UCAR, CERFACS, METEO-FRANCE and IRIT
!----------------------------------------------------------------------
module type_timer

use tools_kinds, only: kind_real
use type_mpl, only: mpl_type

implicit none

! Timer data derived type
type timer_type
   real(kind_real) :: cpu_time_start  ! CPU time start
   real(kind_real) :: cpu_time_end    ! CPU time end
   integer :: count_rate              ! Count rate
   integer :: count_max               ! Count maximum
   integer :: system_clock_start      ! System clock start
   integer :: system_clock_end        ! System clock end
   real(kind_real) :: cpu             ! CPU time
   real(kind_real) :: elapsed         ! Elapsed time
contains
   procedure :: start => timer_start
   procedure :: end => timer_end
   procedure :: display => timer_display
end type timer_type

private
public :: timer_type

contains

!----------------------------------------------------------------------
! Subroutine: timer_start
! Purpose: initialize timer
!----------------------------------------------------------------------
subroutine timer_start(timer,mpl)

implicit none

! Passed variables
class(timer_type),intent(inout) :: timer ! Timer data
type(mpl_type),intent(inout) :: mpl      ! MPI data

! Execution times  initialization
if (mpl%main) then
   call system_clock(count_rate=timer%count_rate,count_max=timer%count_max)
   call system_clock(count=timer%system_clock_start)
   call cpu_time(timer%cpu_time_start)
end if

end subroutine timer_start

!----------------------------------------------------------------------
! Subroutine: timer_end
! Purpose: finalize timer
!----------------------------------------------------------------------
subroutine timer_end(timer,mpl)

implicit none

! Passed variables
class(timer_type),intent(inout) :: timer ! Timer data
type(mpl_type),intent(inout) :: mpl      ! MPI data

if (mpl%main) then
   ! Execution times calculation
   call system_clock(count=timer%system_clock_end)
   call cpu_time(timer%cpu_time_end)
   timer%cpu = timer%cpu_time_end-timer%cpu_time_start
   if (timer%system_clock_end<timer%system_clock_start) then
      timer%elapsed = real(timer%system_clock_end-timer%system_clock_start+timer%count_max,kind_real) &
 & /real(timer%count_rate,kind_real)
   else
      timer%elapsed = real(timer%system_clock_end-timer%system_clock_start,kind_real) &
 & /real(timer%count_rate,kind_real)
   end if
end if

! Broadcast
call mpl%f_comm%broadcast(timer%cpu,mpl%rootproc-1)
call mpl%f_comm%broadcast(timer%elapsed,mpl%rootproc-1)

end subroutine timer_end

!----------------------------------------------------------------------
! Subroutine: timer_display
! Purpose: display timer
!----------------------------------------------------------------------
subroutine timer_display(timer,mpl)

implicit none

! Passed variables
class(timer_type),intent(inout) :: timer ! Timer data
type(mpl_type),intent(inout) :: mpl      ! MPI data

! Execution times calculation
call timer%end(mpl)

! Display
write(mpl%info,'(a,f8.3,a)') '--- CPU time:                   ',timer%cpu,' s'
call mpl%flush
write(mpl%info,'(a,f8.3,a)') '--- Elapsed time:               ',timer%elapsed,' s'
call mpl%flush
if (timer%elapsed>0.0) then
   write(mpl%info,'(a,f8.3)') '--- CPU/elapsed ratio:          ',timer%cpu/timer%elapsed
   call mpl%flush
end if

end subroutine timer_display

end module type_timer
