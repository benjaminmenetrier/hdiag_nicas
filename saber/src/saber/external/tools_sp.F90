! (C) Copyright 2018-2019 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
module tools_sp

use tools_kinds, only: kind_real
use tools_const, only: pi
!use type_mpl, only: mpl_type

implicit none

private
real(kind=kind_real),parameter:: ZERO    = 0.0_kind_real
real(kind=kind_real),parameter:: ONE     = 1.0_kind_real
real(kind=kind_real),parameter:: TWO     = 2.0_kind_real
real(kind=kind_real),parameter:: TEN     = 10.0_kind_real
real(kind=kind_real),parameter:: HALF    = 0.5_kind_real
real(kind=kind_real),parameter:: QUARTER = 0.25_kind_real

public :: splat

contains

!-----------------------------------------------------------------
! compute latitude functions
subroutine splat(IDRT,JMAX,SLAT,WLAT)
! ----------------------------------------------------------------
! INPUT ARGUMENT LIST:
!   IDRT     - INTEGER GRID IDENTIFIER
!              (IDRT=4 FOR GAUSSIAN GRID,
!               IDRT=0 FOR EQUALLY-SPACED GRID INCLUDING POLES,
!               IDRT=256 FOR EQUALLY-SPACED GRID EXCLUDING POLES)
!   JMAX     - INTEGER NUMBER OF LATITUDES.
!
! OUTPUT ARGUMENT LIST:
!   SLAT     - REAL (JMAX) SINES OF LATITUDE.
!   WLAT     - REAL (JMAX) GAUSSIAN WEIGHTS.
! ----------------------------------------------------------------
  implicit none
  integer,             intent(in ):: IDRT,JMAX
  real(kind=kind_real),intent(out):: SLAT(JMAX),WLAT(JMAX)
  real(kind=kind_real):: PK(JMAX/2),PKM1(JMAX/2),PKM2(JMAX/2)
  real(kind=kind_real):: SLATD(JMAX/2),SP,SPMAX,EPS
  integer,parameter:: JZ=50
  real(kind=kind_real):: BZ(JZ)
  real(kind=kind_real):: DLT,D1,d,R
  real(kind=kind_real):: AWORK((JMAX+1)/2,((JMAX+1)/2))
  real(kind=kind_real):: BWORK(((JMAX+1)/2))
  integer:: JH,JHE,JHO,J0
  integer:: IPVT((JMAX+1)/2)
  real(kind=kind_real),parameter:: C=(ONE-(TWO/PI)**2)*QUARTER
  integer:: J,JS,N

  data BZ / 2.4048255577_kind_real,  5.5200781103_kind_real, &
 &          8.6537279129_kind_real, 11.7915344391_kind_real, &
 &         14.9309177086_kind_real, 18.0710639679_kind_real, &
 &         21.2116366299_kind_real, 24.3524715308_kind_real, &
 &         27.4934791320_kind_real, 30.6346064684_kind_real, &
 &         33.7758202136_kind_real, 36.9170983537_kind_real, &
 &         40.0584257646_kind_real, 43.1997917132_kind_real, &
 &         46.3411883717_kind_real, 49.4826098974_kind_real, &
 &         52.6240518411_kind_real, 55.7655107550_kind_real, &
 &         58.9069839261_kind_real, 62.0484691902_kind_real, &
 &         65.1899648002_kind_real, 68.3314693299_kind_real, &
 &         71.4729816036_kind_real, 74.6145006437_kind_real, &
 &         77.7560256304_kind_real, 80.8975558711_kind_real, &
 &         84.0390907769_kind_real, 87.1806298436_kind_real, &
 &         90.3221726372_kind_real, 93.4637187819_kind_real, &
 &         96.6052679510_kind_real, 99.7468198587_kind_real, &
 &         102.888374254_kind_real, 106.029930916_kind_real, &
 &         109.171489649_kind_real, 112.313050280_kind_real, &
 &         115.454612653_kind_real, 118.596176630_kind_real, &
 &         121.737742088_kind_real, 124.879308913_kind_real, &
 &         128.020877005_kind_real, 131.162446275_kind_real, &
 &         134.304016638_kind_real, 137.445588020_kind_real, &
 &         140.587160352_kind_real, 143.728733573_kind_real, &
 &         146.870307625_kind_real, 150.011882457_kind_real, &
 &         153.153458019_kind_real, 156.295034268_kind_real /

 EPS=TEN*epsilon(SP)
 D1=ONE
 J0=0

! -------------------
! Gaussian latitudes
  if(IDRT==4) then
    JH=JMAX/2
    JHE=(JMAX+1)/2
    R=ONE/sqrt((real(JMAX,kind_real)+HALF)**2+C)
    do J=1,min(JH,JZ)
      SLATD(J)=cos(BZ(J)*R)
    end do
    do J=JZ+1,JH
      SLATD(J)=cos((BZ(JZ)+(J-JZ)*PI)*R)
    end do
    SPMAX=ONE
    do while(SPMAX>EPS)
      SPMAX=ZERO
      do J=1,JH
        PKM1(J)=ONE
        PK(J)=SLATD(J)
      end do
      do N=2,JMAX
        do J=1,JH
          PKM2(J)=PKM1(J)
          PKM1(J)=PK(J)
          PK(J)=real((2*N-1)*SLATD(J)*PKM1(J)-(N-1)*PKM2(J),kind_real) &
         &     /real(N,kind_real)
        end do
      end do
      do J=1,JH
        SP=PK(J)*(ONE-SLATD(J)**2)/(JMAX*(PKM1(J)-SLATD(J)*PK(J)))
        SLATD(J)=SLATD(J)-SP
        SPMAX=max(SPMAX,abs(SP))
      end do
    end do
    do J=1,JH
      SLAT(J)=SLATD(J)
      WLAT(J)=(TWO*(ONE-SLATD(J)**2))/(JMAX*PKM1(J))**2
      SLAT(JMAX+1-J)=-SLAT(J)
      WLAT(JMAX+1-J)=WLAT(J)
    end do
    if(JHE>JH) then
      SLAT(JHE)=ZERO
      WLAT(JHE)=TWO/JMAX**2
      do N=2,JMAX,2
        WLAT(JHE)=WLAT(JHE)*N**2/(N-1)**2
      end do
    end if
! -----------------------------------------
! equally-spaced latitudes including poles
  else if(IDRT==0) then
    JH=JMAX/2
    JHE=(JMAX+1)/2
    JHO=JHE-1
    DLT=PI/(JMAX-1)
    SLAT(1)=ONE
    do J=2,JH
      SLAT(J)=cos(real((J-1),kind_real)*DLT)
    end do
    do JS=1,JHO
      do J=1,JHO
        AWORK(JS,J)=cos(real(2*(JS-1)*J,kind_real)*DLT)
      end do
    end do
    do JS=1,JHO
      BWORK(JS)=-D1/real((4*(JS-1)**2-1),kind_real)
    end do
    call ludcmp(awork,jho,jhe,ipvt)
    call lubksb(awork,jho,jhe,ipvt,bwork)
    WLAT(1)=ZERO
    do J=1,JHO
      WLAT(J+1)=BWORK(J)
    end do
    do J=1,JH
      SLAT(JMAX+1-J)=-SLAT(J)
      WLAT(JMAX+1-J)=WLAT(J)
    end do
    if(JHE>JH) then
      SLAT(JHE)=ZERO
      WLAT(JHE)=TWO*WLAT(JHE)
    end if

! -----------------------------------------
! equally-spaced latitudes excluding poles
  else if(IDRT==256) then
    JH=JMAX/2
    JHE=(JMAX+1)/2
    JHO=JHE
    DLT=PI/JMAX
    SLAT(1)=ONE
    do J=1,JH
      SLAT(J)=cos((real(J,kind_real)-HALF)*DLT)
    end do
    do JS=1,JHO
      do J=1,JHO
        AWORK(JS,J)=cos(real(2*(JS-1),kind_real) &
       &              *(real(J,kind_real)-HALF)*DLT)
      end do
    end do
    do JS=1,JHO
      BWORK(JS)=-D1/real(4*(JS-1)**2-1,kind_real)
    end do
    call ludcmp(awork,jho,jhe,ipvt,d)
    call lubksb(awork,jho,jhe,ipvt,bwork)
    WLAT(1)=ZERO
    do J=1,JHO
      WLAT(J)=BWORK(J)
    end do
    do J=1,JH
      SLAT(JMAX+1-J)=-SLAT(J)
      WLAT(JMAX+1-J)=WLAT(J)
    end do
    if(JHE>JH) then
      SLAT(JHE)=ZERO
      WLAT(JHE)=TWO*WLAT(JHE)
    end if
  end if
  return
end subroutine splat

! ------------------------------------------------------------
! solves a system of linear equations, follows call to LUDCMP
subroutine lubksb(A,N,NP,INDX,B)
  implicit none
  integer,             intent(in   ):: NP,N
  real(kind=kind_real),intent(in   ):: A(NP,NP)
  real(kind=kind_real),intent(inout):: B(N)
  integer,             intent(in   ):: INDX(N)
  real(kind=kind_real):: SUM
  integer:: I,II,J,LL

  II=0
  do I=1,N
    LL=INDX(I)
    SUM=B(LL)
    B(LL)=B(I)
    if(II/=0) then
      do J=II,I-1
        SUM=SUM-A(I,J)*B(J)
      end do
    else if(ABS(SUM)>ZERO) then
      II=I
    end if
    B(I)=SUM
  end do
  do I=N,1,-1
    SUM=B(I)
    if(I<N) then
      do J=I+1,N
        SUM=SUM-A(I,J)*B(J)
      end do
    end if
    B(I)=SUM/A(I,I)
  end do
  return
end subroutine lubksb

! ---------------------------------------------------
! replaces an NxN matrix A with the LU decomposition
subroutine ludcmp(A,N,NP,INDX,D)
  implicit none
  integer,             intent(in   ):: N,NP
  real(kind=kind_real),intent(inout):: A(NP,NP)
  integer,             intent(out  ):: INDX(N)
  real(kind=kind_real),intent(out  ),optional:: D
  real(kind=kind_real),parameter:: TINY=1.0E-20
  real(kind=kind_real):: AAMAX,SUM,DUM
  real(kind=kind_real):: VV(N)
  integer:: IMAX
  integer:: I,J,K

  D=ONE
  do I=1,N
    AAMAX=ZERO
    do J=1,N
      if(abs(A(I,J))>AAMAX) AAMAX=abs(A(I,J))
    end do
    if(.NOT.(ABS(AAMAX)>ZERO)) print *, 'SINGULAR MATRIX.'
    VV(I)=ONE/AAMAX
  end do
  do J=1,N
    if(J>1) then
      do I=1,J-1
        SUM=A(I,J)
        if(I>1) then
          do K=1,I-1
            SUM=SUM-A(I,K)*A(K,J)
          end do
          A(I,J)=SUM
        end if
      end do
    end if
    AAMAX=ZERO
    do I=J,N
      SUM=A(I,J)
      if(J>1) then
        do K=1,J-1
          SUM=SUM-A(I,K)*A(K,J)
        end do
        A(I,J)=SUM
      end if
      DUM=VV(I)*abs(SUM)
      if(DUM>=AAMAX) then
        IMAX=I
        AAMAX=DUM
      end if
    end do
    if(J/=IMAX) then
      do K=1,N
        DUM=A(IMAX,K)
        A(IMAX,K)=A(J,K)
        A(J,K)=DUM
      end do
      D=-D
      VV(IMAX)=VV(J)
    end if
    INDX(J)=IMAX
    if(J/=N) then
      if(.NOT.(ABS(A(J,J))>ZERO)) A(J,J)=TINY
      DUM=ONE/A(J,J)
      do I=J+1,N
        A(I,J)=A(I,J)*DUM
      end do
    end if
  end do
  if(.NOT.(ABS(A(N,N))>ZERO)) A(N,N)=TINY
  return
end subroutine ludcmp

end module tools_sp
