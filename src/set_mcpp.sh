#!/bin/sh
# script to set MCPP to be called from gcc
# ./set_mcpp.sh $gcc_path $gcc_maj_ver $gcc_min_ver $cpp_call $CC   \
#       $CXX x$EXEEXT $LN_S $inc_dir $host_system $cpu $target_cc

gcc_maj_ver=$2
gcc_min_ver=$3
cpp_call=$4
CC=$5
CXX=$6
LN_S=$8
inc_dir=$9
host_system=${10}
if test $host_system = SYS_MAC; then
    cpu=${11}
    target_cc=${12}
    target=`echo $target_cc | sed 's/-gcc.*$//'`
fi
cpp_name=`echo $cpp_call | sed 's,.*/,,'`
cpp_path=`echo $cpp_call | sed "s,/$cpp_name,,"`
gcc_path=`echo $1 | sed "s,/${CC}\$,,"`

# remove ".exe" or such
EXEEXT=`echo $7 | sed 's/^x//'`
if test x$EXEEXT != x; then
    cpp_base=`echo $cpp_name | sed "s/${EXEEXT}//"`
else
    cpp_base=$cpp_name
fi

if test $host_system = SYS_MINGW && test ! -f cc1$EXEEXT; then
    ## cc1.exe has not yet compiled
    echo "  do 'make COMPILER=GNUC mcpp cc1'; then do 'make COMPILER=GNUC install'"
    exit 1
fi

gen_headers() {
    echo "  mkdir -p $hdir"
    mkdir -p $hdir
    if test ! -f $hdir/gcc$gcc_maj_ver${gcc_min_ver}_predef_std.h; then
        echo "  generating g*.h header files"
        $CC -E -xc $arg -dM /dev/null | sort | grep ' *#define *_'      \
                > $hdir/gcc$gcc_maj_ver${gcc_min_ver}_predef_std.h
        $CC -E -xc $arg -dM /dev/null | sort |                  \
                grep -E ' *#define *[A-Za-z]+'                  \
                > $hdir/gcc$gcc_maj_ver${gcc_min_ver}_predef_old.h
        $CXX -E -xc++ $arg -dM /dev/null | sort | grep ' *#define *_'   \
                > $hdir/gxx$gcc_maj_ver${gcc_min_ver}_predef_std.h
        $CXX -E -xc++ $arg -dM /dev/null | sort |               \
                grep -E ' *#define *[A-Za-z]+'                  \
                > $hdir/gxx$gcc_maj_ver${gcc_min_ver}_predef_old.h
    fi
}

cwd=`pwd`
echo "  cd $inc_dir"
cd $inc_dir

if test $host_system = SYS_MAC; then
## Apple-GCC changes architecture and predefined macros by -arch * option
    if test $cpu = i386 || test $cpu = x86_64; then
        arch0=i386
        arch1=x86_64
    else
        arch0=ppc
        arch1=ppc64
    fi
    for arch in $arch0 $arch1
    do                              ## generate headers for 2 architectures
        hdir=mcpp-gcc-$arch
        arg="-arch $arch"
        gen_headers
    done
else
if test $host_system = SYS_CYGWIN; then
    ## CYGWIN has 'mingw' include directory for '-mno-cygwin' option
    for hdir in mcpp-gcc mingw/mcpp-gcc
    do
        if test $hdir = mingw/mcpp-gcc; then
            arg='-mno-cygwin'
        else
            arg=
        fi
        gen_headers
    done
else
    hdir=mcpp-gcc
    arg=
    gen_headers
fi
fi

# write shell-script so that call of 'cpp0', 'cc1 -E' or so is replaced to
# call of mcpp
echo "  cd $cpp_path"
cd $cpp_path

# other than MinGW
if test $host_system != SYS_MINGW; then
    # for GCC V.3.3 and later
    if test x$cpp_base = xcc1; then
        for cpp in cc1 cc1plus
        do
            if test $cpp = cc1; then
                shname=mcpp
            else
                shname=mcpp_plus
            fi
            cat > $shname.sh <<_EOF
#!/bin/sh
for i in \$@
do
    case \$i in
        -fpreprocessed|-traditional*)
            $cpp_path/${cpp}_gnuc "\$@"
            exit ;;
    esac
done
_EOF
        done
    fi
    
    # for GCC V.2, V.3 and V.4
    mcpp_name=mcpp
    if test $host_system = SYS_MAC && test -f ${target}-mcpp; then
        mcpp_name=${target}-mcpp    ## long name of Mac OS X cross-compiler
    fi
    echo $cpp_path/$mcpp_name '"$@"'   >>  mcpp.sh
    chmod a+x mcpp.sh
    if test x$cpp_base = xcc1; then
        echo $cpp_path/$mcpp_name -+ '"$@"'  >> mcpp_plus.sh
        chmod a+x mcpp_plus.sh
    fi
fi

# backup GCC / cpp or cc1, cc1plus
mcpp_installed=`$cpp_call -v /dev/null 2>&1 | grep "MCPP"`
if test "x$mcpp_installed" = x; then            # mcpp has not installed
    sym_link=
    if test $host_system = SYS_MINGW; then
        if test -f cc1_gnuc$EXEEXT; then
            sym_link=l          ## cc1.exe already moved to cc1_gnuc.exe
        fi
    else
        if test -h $cpp_name; then
            sym_link=l
        fi
    fi
    if test x$sym_link != xl; then
        echo "  mv $cpp_name ${cpp_base}_gnuc$EXEEXT"
        mv -f $cpp_name ${cpp_base}_gnuc$EXEEXT
        if test x$cpp_base = xcc1; then
            echo "  mv cc1plus$EXEEXT cc1plus_gnuc$EXEEXT"
            mv -f cc1plus$EXEEXT cc1plus_gnuc$EXEEXT
        fi
    fi
fi
if test -f $cpp_name; then
    rm -f $cpp_name
    if test x$cpp_base = xcc1; then
        rm -f cc1plus$EXEEXT
    fi
fi

# make symbolic link of mcpp.sh to 'cpp0' or 'cc1', 'cc1plus'
if test $host_system = SYS_MINGW; then
    echo "  cp $cwd/cc1$EXEEXT"
    cp $cwd/cc1$EXEEXT .
    strip cc1$EXEEXT
else
    echo "  $LN_S mcpp.sh $cpp_name"
    $LN_S mcpp.sh $cpp_name
fi
if test x$cpp_base = xcc1; then
    if test $host_system = SYS_MINGW; then
        echo "  cp cc1$EXEEXT cc1plus$EXEEXT"
        cp cc1$EXEEXT cc1plus$EXEEXT
    else
        echo "  $LN_S mcpp_plus.sh cc1plus$EXEEXT"
        $LN_S mcpp_plus.sh cc1plus$EXEEXT
    fi
fi

if test x$gcc_maj_ver = x2; then
    exit 0
fi

# for GCC V.3 or V.4 make ${CC}.sh and ${CXX}.sh to add -no-integrated-cpp
# option
echo "  cd $gcc_path"
cd $gcc_path

if test $host_system = SYS_MAC && test x${target_cc} != x; then
    # cross-compiler on Mac OS X 
    CC_=$target_cc
    CXX_=`echo $target_cc | sed 's/gcc/g++/'`
else
    CC_=$CC
    CXX_=$CXX
fi

for cc in $CC_ $CXX_
do
    entity=$cc$EXEEXT
    if test $host_system != SYS_MINGW; then
        ref=$cc$EXEEXT
        while ref=`readlink $ref`
        do
            entity=$ref;
        done
        if test $entity = $cc.sh; then          # gcc.sh already installed
            exit 0
        fi
    fi
    ccache=`echo $entity | grep ccache`
    if test x$ccache != x; then
        ## CC (CXX) is a symbolic link to ccache
        ## search the real $cc in $PATH
        for path in `echo $PATH | sed 's/:/ /g'`
        do
            if test -f $path/$cc$EXEEXT && test $gcc_path != $path; then
                break;
            fi
        done
        gcc_path=$path
        echo "  cd $gcc_path"
        cd $gcc_path
        entity=$cc
        ref=$cc
        while ref=`readlink $ref`
        do
            entity=$ref;
        done
        if test $entity = $cc.sh; then
            exit 0
        fi
    fi
    if test x$EXEEXT != x; then
        entity_base=`echo $entity | sed "s/$EXEEXT//"`
    else
        entity_base=$entity
    fi
    if test $host_system != SYS_MINGW     \
            || test ! -f ${entity_base}_proper$EXEEXT; then
        echo "  mv $entity ${entity_base}_proper$EXEEXT"
        mv -f $entity ${entity_base}_proper$EXEEXT
    fi
    if test x"`echo $entity | grep '^/'`" = x; then     # not absolute path
        prefix_dir=$gcc_path/
    else                                # absolute path
        prefix_dir=
    fi
    echo '#! /bin/sh' > $cc.sh
    echo $prefix_dir${entity_base}_proper -no-integrated-cpp '"$@"' >> $cc.sh
    chmod a+x $cc.sh
    echo "  $LN_S $cc.sh $cc"
    $LN_S -f $cc.sh $cc
    if test $cc != $entity; then
        $LN_S -f $cc.sh $entity
    fi
done

