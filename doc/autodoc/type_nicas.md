# Module type_nicas

| Type | Name | Purpose |
| :--: | :--: | :---------- |
| subroutine | [nicas%] [alloc](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L74) | NICAS data allocation |
| subroutine | [nicas%] [dealloc](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L113) | NICAS data deallocation |
| subroutine | [nicas%] [read](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L141) | read NICAS data |
| subroutine | [nicas%] [write](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L284) | write NICAS data |
| subroutine | [nicas%] [write_mpi_summary](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L391) | write NICAS MPI related data summary |
| subroutine | [nicas%] [run_nicas](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L474) | NICAS driver |
| subroutine | [nicas%] [run_nicas_tests](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L540) | NICAS tests driver |
| subroutine | [nicas%] [alloc_cv](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L670) | control vector allocation |
| subroutine | [nicas%] [random_cv](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L722) | generate a random control vector |
| subroutine | [nicas%] [apply](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L749) | apply NICAS |
| subroutine | [nicas%] [apply_from_sqrt](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1004) | apply NICAS from square-root |
| subroutine | [nicas%] [apply_sqrt](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1046) | apply NICAS square-root |
| subroutine | [nicas%] [apply_sqrt_ad](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1247) | apply NICAS square-root, adjoint |
| subroutine | [nicas%] [randomize](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1468) | randomize NICAS from square-root |
| subroutine | [nicas%] [apply_bens](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1539) | apply localized ensemble covariance |
| subroutine | [nicas%] [apply_bens_noloc](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1598) | apply ensemble covariance, without localization |
| subroutine | [nicas%] [test_adjoint](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1653) | test NICAS adjoint |
| subroutine | [nicas%] [test_sqrt](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1735) | test full/square-root equivalence |
| subroutine | [nicas%] [test_dirac](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1850) | apply NICAS to diracs |
| subroutine | [nicas%] [test_randomization](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L1916) | test NICAS randomization method with respect to theoretical error statistics |
| subroutine | [nicas%] [test_consistency](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L2019) | test HDIAG-NICAS consistency with a randomization method |
| subroutine | [nicas%] [test_optimality](https://github.com/benjaminmenetrier/bump/tree/master/src/type_nicas.F90#L2106) | test HDIAG localization optimality with a randomization method |