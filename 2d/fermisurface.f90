! calculate bulk's energy band using wannier TB method
  subroutine fermisurface

     use wmpi
     use para

     implicit none

     integer :: ik, i, j, ikx, iky
     integer :: nkx
     integer :: nky

     integer :: ierr
     real(dp) :: kz
     real(Dp) :: k(2)
     
     ! Hamiltonian of bulk system
     complex(Dp) :: Hamk_bulk(Num_wann,Num_wann) 

     real(dp) :: zmin, zmax
     real(dp) :: kxmin, kxmax, kymin, kymax
     real(dp) :: kxmin_shape, kxmax_shape, kymin_shape, kymax_shape

     real(dp), allocatable :: kxy(:,:)
     real(dp), allocatable :: kxy_shape(:,:)
     
     real(dp), allocatable :: dos(:)
     real(dp), allocatable :: dos_mpi(:)

     complex(dp), allocatable :: ones(:,:)

     nkx= Nk1
     nky= Nk2
     allocate( kxy(2, nkx*nky))
     allocate( kxy_shape(2, nkx*nky))
     kxy=0d0
     kxy_shape=0d0

     ik=0
     do ikx=1, Nk1
        do iky=1, Nk2
           ik= ik+ 1
           kxy(:, ik)= K2D_start+ K2D_vec1*(ikx-1)/dble(nk1-1)  &
                + K2D_vec2*(iky-1)/dble(nk2-1)  
           kxy_shape(:, ik)= kxy(1,ik)*kua+ kxy(2, ik)*kub
        enddo
     enddo

     kxmin_shape= minval(kxy_shape(1, :))
     kxmax_shape= maxval(kxy_shape(1, :))
     kymin_shape= minval(kxy_shape(2, :))
     kymax_shape= maxval(kxy_shape(2, :))

     allocate( dos    (Nk1*Nk2))
     allocate( dos_mpi(Nk1*Nk2))
     dos    = 0d0
     dos_mpi= 0d0

     allocate(ones(Num_wann, Num_wann))
     ones= 0d0
     do i=1, Num_wann
        ones(i, i)= 1d0
     enddo
     do ik= 1+cpuid, Nk1*Nk2, num_cpu
        if (cpuid==0) write(stdout, *),'FS, ik, knv3' , ik, Nk1*Nk2

        k(1) = kxy(1, ik)
        k(2) = kxy(2, ik)

        ! calculation bulk hamiltonian
        Hamk_bulk= 0d0
        call ham_bulk(k, Hamk_bulk)

        Hamk_bulk= (E_arc -zi* eta_arc)* ones - Hamk_bulk
        call inv(Num_wann, Hamk_bulk)
        do i=1, Num_wann
           dos(ik)= dos(ik)+ aimag(Hamk_bulk(i, i))/pi
        enddo

     enddo

     call mpi_allreduce(dos,dos_mpi,size(dos),&
                       mpi_dp,mpi_sum,mpi_cmw,ierr)

     if (cpuid==0)then
        open(unit=14, file='fs.dat')
   
        do ik=1, Nk1*Nk2
           write(14, '(3f16.8)')kxy_shape(:, ik), log(dos_mpi(ik))
           if (mod(ik, nky)==0) write(14, *)' '
        enddo
        close(14)
     endif
     zmax= maxval(log(dos_mpi))
     zmin= minval(log(dos_mpi))

     !> minimum and maximum value of energy bands

     !> write script for gnuplot
     if (cpuid==0) then
        open(unit=101, file='fs.gnu')
        write(101, '(a)')"set encoding iso_8859_1"
        write(101, '(a)')'#set terminal  postscript enhanced color'
        write(101, '(a)')"#set output 'fs.eps'"
        write(101, '(3a)')'set terminal  pngcairo truecolor enhanced', &
           ' size 1920, 1680 font ",36"'
        write(101, '(a)')"set output 'fs.png'"
        write(101,'(a, f10.4, 2a, f10.4, a)') &
           'set palette defined ( ', zmin, ' "white", ', &
          '0 "black", ', zmax,'  "red" )'
        write(101, '(a)')'#set palette rgbformulae 33,13,10'
        write(101, '(a)')'unset ztics'
        write(101, '(a)')'unset key'
        write(101, '(a)')'set pm3d'
        write(101, '(a)')'#set view equal xyz'
        write(101, '(a)')'set view map'
        write(101, '(a)')'set border lw 3'
        write(101, '(a)')'#set xtics font ",24"'
        write(101, '(a)')'#set ytics font ",24"'
        write(101, '(a)')'set size ratio -1'
        write(101, '(a)')'unset xtics'
        write(101, '(a)')'unset ytics'
        write(101, '(a)')'set colorbox'
       !write(101, '(a, f10.5, a, f10.5, a)')'set xrange [', kxmin, ':', kxmax, ']'
       !write(101, '(a, f10.5, a, f10.5, a)')'set yrange [', kymin, ':', kymax, ']'
        write(101, '(a, f10.5, a, f10.5, a)')'set xrange [', kxmin_shape, ':', kxmax_shape, ']'
        write(101, '(a, f10.5, a, f10.5, a)')'set yrange [', kymin_shape, ':', kymax_shape, ']'
        write(101, '(a)')'set pm3d interpolate 2,2'
        write(101, '(2a)')"splot 'fs.dat' u 1:2:3 w pm3d"

        close(101)
     endif


   return
   end subroutine fermisurface

!  calculate bulk's energy band using wannier TB method
   subroutine gapshape

      use wmpi
      use para
      
      implicit none
      
      integer :: ik, i, j, ikx, iky
      integer :: nkx
      integer :: nky
      
      integer :: ierr, i1, i2
      real(Dp) :: k(2)
      
      ! Hamiltonian of bulk system
      complex(Dp) :: Hamk_bulk(Num_wann,Num_wann) 
      
      real(dp) :: zmin, zmax
      real(dp) :: kxmin_shape, kxmax_shape, kymin_shape, kymax_shape
      
      real(dp), allocatable :: kxy(:,:)
      real(dp), allocatable :: kxy_shape(:,:)
      
      real(dp), allocatable :: gap(:, :)
      real(dp), allocatable :: gap_mpi(:, :)
      real(dp), allocatable :: W(:)
      
      complex(dp), allocatable :: ones(:,:)
      
      nkx= Nk
      nky= Nk
      allocate( kxy(2, nkx*nky))
      allocate( kxy_shape(2, nkx*nky))
      kxy=0d0
      kxy_shape=0d0
      
     
      ik=0
      do ikx=1, Nk1
         do iky=1, Nk2
            ik= ik+ 1
            kxy(:, ik)= K2D_start+ K2D_vec1*(ikx-1)/dble(nk1-1)  &
                 + K2D_vec2*(iky-1)/dble(nk2-1)  
            kxy_shape(:, ik)= kxy(1,ik)*kua+ kxy(2, ik)*kub
         enddo
      enddo

      kxmin_shape=minval(kxy_shape(1,:))
      kxmax_shape=maxval(kxy_shape(1,:))
      kymin_shape=minval(kxy_shape(2,:))
      kymax_shape=maxval(kxy_shape(2,:))
      
      
      allocate( gap    (3, Nk1*Nk2))
      allocate( gap_mpi(3, Nk1*Nk2))
      gap    = 0d0
      gap_mpi= 0d0
      
      allocate(W(Num_wann))
      allocate(ones(Num_wann, Num_wann))
      W= 0d0
      ones= 0d0
      do i=1, Num_wann
         ones(i, i)= 1d0
      enddo
      
      if (Numoccupied> Num_wann) then
         stop 'Numoccupied should less than Num_wann'
      endif
      
      do ik= 1+cpuid, Nk1*Nk2, num_cpu
         if (cpuid==0)write(stdout, *)'Gap plane', ik, Nk1*Nk2
      
         k(1) = kxy(1, ik)
         k(2) = kxy(2, ik)
      
         !> calculation bulk hamiltonian
         Hamk_bulk= 0d0
         call ham_bulk(k, Hamk_bulk)
     
         !> diagonalization
         call eigensystem_c( 'N', 'U', Num_wann ,Hamk_bulk, W)
         gap(1, ik)= W(Numoccupied+1)- W(Numoccupied)
         gap(2, ik)= W(Numoccupied)
         gap(3, ik)= W(Numoccupied+1)
      
      enddo
      
      call mpi_allreduce(gap,gap_mpi,size(gap),&
                        mpi_dp,mpi_sum,mpi_cmw,ierr)
      
      if (cpuid==0)then
         open(unit=14, file='GapPlane.dat')
     
         write(14, '(100a16)')'# kx', 'ky', 'gap', 'Ev', 'Ec', 'k1', 'k2'
         do ik=1, Nk1*Nk2
            write(14, '(30f16.8)')kxy_shape(:, ik), (gap_mpi(:, ik)), kxy(:, ik)
            if (mod(ik, nky)==0) write(14, *)' '
         enddo
         close(14)

         open(unit=15, file='gap2d.dat')
         write(15, '(100a16)')'kx', 'ky', 'gap', 'Ev', 'Ec', 'k1', 'k2'
         do ik=1, Nk1*Nk2
            if (abs(gap_mpi(1, ik))< 0.10d0) then
               write(15, '(8f16.8)')kxy_shape(:, ik), (gap_mpi(:, ik)), kxy(:, ik)
            endif
         enddo
         close(15)

         open(unit=1116, file='GapPlane_matlab.dat')
     
         write(1116, '(100a16)')'% kx', 'ky', 'gap', 'Ev', 'Ec', 'k1', 'k2'
         do ik=1, Nk1*Nk2
            write(1116, '(30f16.8)')kxy_shape(:, ik), (gap_mpi(:, ik)), kxy(:, ik)
         enddo
         close(1116)

      endif
      
      !> minimum and maximum value of energy bands
      
      zmax= maxval(gap_mpi(1, :))
      zmin= minval(gap_mpi(1, :))
      
      !> write script for gnuplot
      if (cpuid==0) then
         open(unit=103, file='GapPlane.gnu')
         write(103, '(a)')"set encoding iso_8859_1"
         write(103, '(a)')'#set terminal  postscript enhanced color'
         write(103, '(a)')"#set output 'GapPlane.eps'"
         write(103, '(3a)')'#set terminal  pngcairo   truecolor enhanced', &
            '  size 1920, 1680 font ",60"'
         write(103, '(3a)')'set terminal  png   truecolor enhanced', &
            ' size 1920, 1680 font ",60"'
         write(103, '(a)')"set output 'GapPlane.png'"
         write(103,'(a, f10.4, a, f10.4, a, f10.4, a)') &
            'set palette defined ( ', zmin, ' "black", ', &
            (zmin+zmax)/20d0,' "orange", ',zmax,'  "white" )'
         write(103, '(a)')"set origin 0.10, 0.0"
         write(103, '(a)')"set size 0.85, 1.0"
         write(103, '(a)')'unset ztics'
         write(103, '(a)')'unset key'
         write(103, '(a)')'set pm3d'
         write(103, '(a)')'set view map'
         write(103, '(a)')'set border lw 3'
         write(103, '(a)')'#set size ratio -1'
         write(103, '(a)')'set title "Gap in k plane"'
         write(103, '(a)')'set xtics nomirror scale 0.5'
         write(103, '(a)')'set ytics nomirror scale 0.5'
         write(103, '(a)')"set xlabel 'k (1/{\305})'"
         write(103, '(a)')"set ylabel 'k (1/{\305})'"
         write(103, '(a)')'set colorbox'
         write(103, '(a)')'set xrange [ ] noextend'
         write(103, '(a)')'set yrange [ ] noextend'
         write(103, '(a)')'set pm3d interpolate 2,2'
         write(103, '(2a)')"splot 'GapPlane.dat' u 1:2:3 w pm3d"
     
         close(103)
      endif
      
      
      return
   end subroutine gapshape


   !> get fermilevel for the given hamiltonian
   subroutine get_fermilevel
      use wmpi
      use para
      implicit none

      integer :: i1
      integer :: i2
      integer :: i3
      integer :: io
      integer :: ik

      !> number of k points

      integer :: ierr
      integer :: iter
      integer :: itermax

      !> fermi level
      real(dp) :: EF

      real(dp) :: k(3)

      real(dp) ::  Beta 

      real(dp) :: lmin
      real(dp) :: lmax
      real(dp) :: tot


      !> fermi-dirac distribution function
      real(dp), external :: fermi

      !> kpoint coordinates
      real(dp), allocatable :: kpoints(:, :)

      !> eigen value for each kpoint
      real(dp), allocatable :: W(:)
      real(dp), allocatable :: eigvals(:, :)
      real(dp), allocatable :: eigvals_mpi(:, :)

      complex(dp), allocatable :: ham(:, :)


      allocate(W(Num_wann))
      allocate(eigvals(Num_wann, Nk1*Nk2))
      allocate(eigvals_mpi(Num_wann, Nk1*Nk2))
      allocate(ham(Num_wann, Num_wann))
      allocate(kpoints(2, Nk1*Nk2))
      eigvals= 0d0
      eigvals_mpi= 0d0
      ham= 0d0
      kpoints= 0d0
      Beta= 200d0

      ik= 0
      do i1=1, Nk
      do i2=1, Nk
      do i3=1, Nk
         ik= ik+ 1
         kpoints(1, ik)= (i1-1d0)/dble(Nk)
         kpoints(2, ik)= (i2-1d0)/dble(Nk)
         kpoints(3, ik)= (i3-1d0)/dble(Nk)
      enddo
      enddo
      enddo

      do ik=1+ cpuid, Nk1*Nk2, num_cpu
 
         ham= 0d0
         k= kpoints(:, ik)
         call ham_bulk(k, ham)
         call eigensystem_c( 'N', 'U', num_wann, ham, W)
         eigvals_mpi(:, ik)= W
      enddo ! ik

      call mpi_allreduce(eigvals_mpi, eigvals, size(eigvals), &
                         mpi_dp, mpi_sum, mpi_cmw, ierr)

      ! using bisection algorithm to search the fermi level
      iter= 0 
      itermax= 100
      tot= 9999d0
      lmin= minval(eigvals)
      lmax= maxval(eigvals)
      if (cpuid==0) print *, 'Emin= ', lmin
      if (cpuid==0) print *, 'Emax= ', lmax
      do while( abs(tot- Ntotch).gt. eps6 .and. iter.lt.itermax)

         iter= iter+ 1

         EF= (lmin+ lmax)* half

         tot= 0d0
         do ik=1, Nk1*Nk2
            do io=1, Num_wann
               tot= tot+ fermi(eigvals(io, ik)- EF, Beta)
            enddo ! io
         enddo ! ik
         tot= tot/dble(Nk1*Nk2)

         if (tot > Ntotch)then
            lmax= EF
         else
            lmin= EF
         endif

         if (cpuid==0) then
             write(stdout, 100)iter, tot-Ntotch, EF, '  Charge: ', tot
         endif
      100   format(2x,">iter",i4,2x,"diff:",f12.6,2x,"EF: ",f12.6,a,f12.6)

      enddo ! bisection

      E_fermi= EF

      return
   end subroutine get_fermilevel

   !------------+------------+------------+------------+------------+--------+!
   ! calculate the Fermi-Dirac distribution
   !------------+------------+------------+------------+------------+--------+!
   function fermi(omega, Beta) result(value)

      use para
      implicit none

      ! >> inout variables
      real(dp), intent(in) :: omega
      real(dp), intent(in) :: Beta

      ! return value
      real(dp) :: value
    
      ! avoid numerical instability 
      if (beta*omega .ge. 20d0) then
         value = zero
      elseif (beta*omega.le. -20d0)then
         value = one
      else
         value= one/(one+exp(beta*omega))
      endif

      return
   end function fermi



