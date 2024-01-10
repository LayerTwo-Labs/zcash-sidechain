## Build from Source (Sidechain Version)

### Non-Nix (Ubuntu)

First, install the Zcash build dependencies. These can be found on the 
official [Zcash docs](https://zcash.readthedocs.io/en/master/rtd_pages/Debian-Ubuntu-build.html). 
Only install the dependencies listed in the `apt-get` block, and skip 
the rest of the instructions. 

Once you have installed the build dependencies:

```bash
# build all dependencies
$ make -C ./depends/

$ ./autogen.sh
$ HOST=$(./depends/config.guess)

# Use the previously compiled dependencies instead of system libraries
$ export CONFIG_SITE="$PWD/depends/$HOST/share/config.site"  

# Configure the build
$ ./configure --disable-tests --disable-bench --disable-hardening --enable-online-rust

# Build the Rust C++ bindings + bridge
$ make -C src cargo-build-lib

# Find the location of the newly compiled Rust C++ bridge library
$ BRIDGE_LOCATION=$(dirname $(./contrib/devtools/find-libcxxbridge.sh))

# Instruct the linker to include the Rust C++ bridge library
$ export LDFLAGS="-L$BRIDGE_LOCATION -lcxxbridge1" 

# Reconfigure the build, taking our freshly compiled Rust C++ bridge into account.
$ ./configure --disable-tests --disable-bench --disable-hardening --enable-online-rust

# Run the actual build
$ make -j # omit the -j if running into memory issues
```

The observant reader will note that this requires a bit of back and forth, which
might seem odd. **Two** calls to `./configure`, what's this??

The issue boils down to the following: 

1. We're building a C++ library based on generated C++ code from Rust sources (in the `make -C src cargo-build-lib` step)
2. This needs to have the same C++ toolchain configuration as the rest of the build
3. The output of this (`libcxxbridge1.a`) must be included in the linker flags (`LDFLAGS`) for the build to succeed
3. However, the Rust libraries have to be in place _before_ we invoke `./configure`... This leads to an awkward chicken-or-egg situation.
4. The solution (it might be a strange one, perhaps there's better options) is to run `./configure` _twice_, and doing the Rust build step in-between.

### Nix - currently not working

To install all dependencies and build zcash-sidechain on ubuntu (22.04) run:

```
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install git curl
# install nix package manager
sh <(curl -L https://nixos.org/nix/install) --daemon
# now follow the instructions and then close and open the terminal (to get nix initialized)
git clone git@github.com:nchashch/zcash-sidechain.git
cd zcash-sidechain
nix-shell # this will install all build tools and dependencies
./autogen.sh
./configure $configureFlags
make -j8 # or number of cores you want to use
```

### Regtest Demo Script

A script for: activating this sidechain (on [drivechain](https://github.com/drivechain-project/mainchain/)), mining blocks, depositing and withdrawing coins, generating t/z addresses and using them, is [available here](zside-tour-2022.sh).


--------------------------



Zcash 5.0.0
<img align="right" width="120" height="80" src="doc/imgs/logo.png">
===========

What is Zcash?
--------------

[Zcash](https://z.cash/) is an implementation of the "Zerocash" protocol.
Based on Bitcoin's code, Zcash intends to offer a far higher standard of privacy
through a sophisticated zero-knowledge proving scheme that preserves
confidentiality of transaction metadata. More technical details are available
in our [Protocol Specification](https://zips.z.cash/protocol/protocol.pdf).

This software is the Zcash client. It downloads and stores the entire history
of Zcash transactions; depending on the speed of your computer and network
connection, the synchronization process could take a day or more once the
blockchain has reached a significant size.

<p align="center">
  <img src="doc/imgs/zcashd_screen.gif" height="500">
</p>

#### :lock: Security Warnings

See important security warnings on the
[Security Information page](https://z.cash/support/security/).

**Zcash is experimental and a work in progress.** Use it at your own risk.

####  :ledger: Deprecation Policy

This release is considered deprecated 16 weeks after the release day. There
is an automatic deprecation shutdown feature which will halt the node some
time after this 16-week period. The automatic feature is based on block
height.

#### Need Help?

* :blue_book: See the documentation at the [ReadTheDocs](https://zcash.readthedocs.io)
  for help and more information.
* :incoming_envelope: Ask for help on the [Zcash](https://forum.z.cash/) forum.
* :speech_balloon: Join our community on [Discord](https://discordapp.com/invite/PhJY6Pm)

Participation in the Zcash project is subject to a
[Code of Conduct](code_of_conduct.md).


License
-------

For license information see the file [COPYING](COPYING).
