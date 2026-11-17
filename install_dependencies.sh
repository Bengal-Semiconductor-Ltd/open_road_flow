#########################################################################
#                        Install Dependencies                           #
#########################################################################

sudo apt update
sudo apt install -y environment-modules
sudo apt install -y build-essential
sudo apt install -y pkg-config 
sudo apt install -y tcl 
sudo apt install -y tcl-dev 
sudo apt install -y libreadline-dev 
sudo apt install -y bison 
sudo apt install -y flex 
sudo apt install -y git 
sudo apt install -y clang 
sudo apt install -y python3 
sudo apt install -y python3-dev 
sudo apt install -y python3-pip
sudo apt install -y pipx
sudo apt install -y python3-virtualenv
sudo apt install -y libpython3-dev 
sudo apt install -y libffi-dev 
sudo apt install -y gcc 
sudo apt install -y g++ 
sudo apt install -y make
sudo apt install -y qtbase5-dev 
sudo apt install -y qttools5-dev 
sudo apt install -y libqt5xmlpatterns5-dev 
sudo apt install -y qtmultimedia5-dev 
sudo apt install -y libqt5multimediawidgets5 
sudo apt install -y libqt5svg5-dev
sudo apt install -y ruby 
sudo apt install -y ruby-dev
sudo apt install -y libz-dev
sudo apt install -y libgit2-dev
sudo apt install -y help2man 
sudo apt install -y perl 
sudo apt install -y g++  # Alternatively, clang
sudo apt install -y libgz  # Non-Ubuntu (ignore if gives error)
sudo apt install -y libfl2  # Ubuntu only (ignore if gives error)
sudo apt install -y libfl-dev  # Ubuntu only (ignore if gives error)
sudo apt install -y zlibc zlib1g zlib1g-dev  # Ubuntu only (ignore if gives error)
sudo apt install -y ccache  # If present at build, needed for run
sudo apt install -y mold  # If present at build, needed for run
sudo apt install -y libgoogle-perftools-dev numactl
sudo apt install -y autoconf
sudo apt update
# ngspice
sudo apt install -y automake
sudo apt install -y libtool
sudo apt install -y libx11-dev
sudo apt install -y libxaw7-dev
sudo apt install -y libxmu-dev
sudo apt install -y libxext-dev
sudo apt install -y libxft-dev
sudo apt install -y libfontconfig1-dev
sudo apt install -y libxrender-dev
sudo apt install -y libfreetype-dev
sudo apt install -y libfftw3-dev
sudo apt install -y libgomp1
# xschem
sudo apt install -y tk-dev
sudo apt install -y libxpm-dev
sudo apt install -y libxcb1-dev
sudo apt install -y libx11-xcb-dev
sudo apt install -y libcairo2-dev
sudo apt install -y libjpeg-dev
sudo apt install -y gawk
sudo apt install -y xterm
# openvaf
sudo apt install -y cargo
sudo apt install -y rustc
sudo apt install -y llvm-18
sudo apt install -y llvm-18-dev
sudo apt install -y libclang-18-dev
sudo apt install -y clang-18
