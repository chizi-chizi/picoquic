#!/bin/bash


CORE_NUM=$(grep -c ^processor /proc/cpuinfo)

CURDIR=`pwd`


PICO_QUIC_DIR=$CURDIR/
PICO_QUIC_BUILD_DIR=$PICO_QUIC_DIR/build
PICO_QUIC_INSTALL=$PICO_QUIC_DIR/INSTALL_DIR

PICO_TLS_DIR=$PICO_QUIC_DIR/picotls
PICO_TLS_BUILD_DIR=$PICO_TLS_DIR/build
PICO_TLS_INSTALL_DIR=$PICO_TLS_DIR/INSTALL_DIR

PTLS_OPENSSL_LIBRARY=$PICO_TLS_BUILD_DIR/libpicotls-core.a
PTLS_OPENSSL_LIBRARY="$PTLS_OPENSSL_LIBRARY $PICO_TLS_BUILD_DIR/libpicotls-minicrypto.a"
PTLS_OPENSSL_LIBRARY="$PTLS_OPENSSL_LIBRARY $PICO_TLS_BUILD_DIR/libpicotls-fusion.a"
PTLS_OPENSSL_LIBRARY="$PTLS_OPENSSL_LIBRARY $PICO_TLS_BUILD_DIR/libpicotls-openssl.a"

fix_ols_cmake_error(){
    #reference to https://unix.stackexchange.com/questions/512681/how-do-i-set-a-cmake-policy#:~:text=Use%20the%20cmake_policy%20command%20to,Wno%2Ddev%20to%20suppress%20it.
    #在第一行前添加字符串cmake_policy(SET CMP0046 OLD),fix error about:
    #CMake Warning (dev) at cmake/dtrace-utils.cmake:37 (ADD_DEPENDENCIES):
    #Policy CMP0046 is not set: Error on non-existent dependency in
    #add_dependencies.  Run "cmake --help-policy CMP0046" for policy details.
    #Use the cmake_policy command to set the policy and suppress this warning.
    head -n 1 picotls/cmake/dtrace-utils.cmake | grep "cmake_policy(SET CMP0046 OLD)" > /dev/null
    if [ $? -ne 0 ]
    then
        echo "sed -i '1icmake_policy(SET CMP0046 OLD)' $PICO_TLS_DIR/cmake/dtrace-utils.cmake"
        sed -i '1icmake_policy(SET CMP0046 OLD)' $PICO_TLS_DIR/cmake/dtrace-utils.cmake
    fi 

}

install_ols_dependency(){
# apt-get install faketime libscope-guard-perl libtest-tcp-perl
# fix error about "Can't locate Net/EmptyPort.pm in @INC (you may need to install the Net::EmptyPort module)" when exec make check 
    dpkg -l | grep faketime > /dev/null
    if [ $? -ne 0 ]
    then 
        echo "apt-get install faketime -y"
        apt-get install faketime -y
    fi

    dpkg -l | grep libscope-guard-perl > /dev/null
    if [ $? -ne 0 ]
    then 
        echo "apt install libscope-guard-perl > /dev/null"
        apt-get install libscope-guard-perl -y
    fi

    dpkg -l | grep libtest-tcp-perl > /dev/null
    if [ $? -ne 0 ]
    then 
        echo "apt-get install libtest-tcp-perl -y"
        apt-get install libtest-tcp-perl -y
    fi
}

fix_cmake_error(){
    fix_ols_cmake_error
}

install_dependency(){
    install_ols_dependency
}

show_help(){
  echo "$0 [ tls | quic | all | pre]"
  echo "tls             build tls"
  echo "quic            build quic"
  echo "all             build tls and quic"
  echo "pre             install depency and fix cmake error"
}

if [ $# -ne 1 ]; then
       show_help 
       exit -1
fi


#picoquic depends picotls so first build picotls

make_tls(){
    pushd  $PICO_QUIC_DIR
    if [ ! -d $PICO_TLS_DIR ] 
    then
        git clone git@github.com:chizi-chizi/picotls.git
    fi
    pushd $PICO_TLS_DIR
        #reference to https://github.com/h2o/picotls
        git submodule init
        git submodule update
    
        if [ ! -d $PICO_TLS_BUILD_DIR ]
        then
            mkdir $PICO_TLS_BUILD_DIR
        else
            rm -rf $PICO_TLS_BUILD_DIR
            mkdir $PICO_TLS_BUILD_DIR
        fi
    
        pushd $PICO_TLS_BUILD_DIR
            cmake .. -DCMAKE_INSTALL_PREFIX=../INSTALL_DIR \
                     -DCMAKE_BUILD_TYPE=Debug
            make  -j $CORE_NUM
            make check
            #make install # current, not support install 
        popd
    popd
    popd 
}

make_quic(){
    pushd $PICO_QUIC_DIR
        if [ ! -d $PICO_QUIC_BUILD_DIR ]
        then
            mkdir $PICO_QUIC_BUILD_DIR
        else
            rm -rf $PICO_QUIC_BUILD_DIR
            mkdir $PICO_QUIC_BUILD_DIR
        fi
    
        pushd $PICO_QUIC_BUILD_DIR
            cmake .. -DCMAKE_INSTALL_PREFIX=../INSTALL_DIR \
                     -DCMAKE_BUILD_TYPE=Debug \
                     -DPTLS_CORE_LIBRARY=$PICO_TLS_BUILD_DIR \
                     -DPTLS_OPENSSL_LIBRARY=$PICO_TLS_BUILD_DIR/libpicotls-openssl.a \
                     -DPTLS_CORE_LIBRARY=$PICO_TLS_BUILD_DIR/libpicotls-core.a \
                     -DPTLS_FUSION_LIBRARY=$PICO_TLS_BUILD_DIR/libpicotls-fusion.a
                     #-DPTLS_OPENSSL_LIBRARY=$PTLS_OPENSSL_LIBRARY
                
                     #-DPTLS_DIR=$PICO_TLS_BUILD_DIR
            make  -j $CORE_NUM
            make install 
            popd
    popd
}

make_pre(){
    fix_cmake_error
    install_dependency
}

make_all(){
    make_pre
    make_tls
    make_quic
}
make_test(){
    echo $PTLS_OPENSSL_LIBRARY
}
case $1 in
all)
    make_all
    ;;
tls)
    make_tls
    ;;
quic)
    make_quic
    ;;
pre)
    make_pre
    ;;
test)
    make_test
    ;;
*)
    show_help 
    ;;
esac


