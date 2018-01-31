#!/bin/ksh

# HDIAG_NICAS source
src=${HOME}/codes/hdiag_nicas/src

if [ $1 == "jedi" ] ; then
   # JEDI directory for HDIAG_NICAS
   dst=${HOME}/codes/jedi/code/jedi-bundle/oops/src/oops/generic/hdiag_nicas

   # Sync
   mkdir -p ${dst}
   rsync -rtvu --delete --exclude "main.f90" ${src}/* ${dst}

   # To copy in ~/codes/jedi/code/jedi-bundle/oops/src/CMakeLists.txt
   echo
   echo "To copy in ~/codes/jedi/code/jedi-bundle/oops/src/CMakeLists.txt:"
   for file in `ls ${HOME}/codes/hdiag_nicas/src` ; do
      if [ "${file}" != "main.f90" ]&&[ "${file}" != "external" ] ; then
         echo oops/generic/hdiag_nicas/${file}
      fi
   done
   for file in `ls ${HOME}/codes/hdiag_nicas/src/external` ; do
      echo oops/generic/hdiag_nicas/external/${file}
   done
fi

if [ $1 == "pack" ] ; then
   # OOPS directory for HDIAG_NICAS
   dst=/home/gmap/mrpa/menetrie/pack/envar-dev.2y/src/local/oops/src/oops/generic/hdiag_nicas

   # Sync
   lftp ftp://menetrie@$2 -e "mirror --delete -X *.lst -X *.mod -X *.o -X *.optrpt -X main.f90 -X yomhook.f90 -e -R $src $dst;quit"
fi

if [ $1 == "sc" ] ; then
   # Directory for HDIAG_NICAS
   dst=/home/gmap/mrpa/menetrie/codes/hdiag_nicas/src

   # Sync
   lftp ftp://menetrie@$2 -e "mirror -e -R $src $dst;quit"
fi
