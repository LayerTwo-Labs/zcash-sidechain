# Using zSide in Regtest Mode
## May 23, 2022 -- Paul Sztorc

### 0. Setup

    # Edit paths to your drivenetd, zsided, drivenet-cli and zside-cli !

  # Terminal window 1

    # Start Drivenet daemon in regtest mode:
    # cd ~/Desktop/drivenet/bin/
    # ./drivechaind -regtest -printtoconsole -rpcuser=user -rpcpassword=pass -server=1 -minerbreakforbmm=1 -rpcport=18443

  # Terminal window 2

    # Start zSide daemon in regtest mode:
    # cd ~/Desktop/zcash-sidechain/src/
    # ./zcashd -regtest -printtoconsole -rpcuser=user -rpcpassword=pass -mainchainrpcport=18443 -rpcport=2048 -nuparams=5ba81b19:1 -nuparams=76b809bb:1

    # touch ~/.zcash/zcash.conf # if needed: this makes the conf file, which is required on the first run.
    # see: https://forum.zcashcommunity.com/t/sending-funds-to-z-addr-in-regtest-mode/32612 for the explaination behind 'nuparams'




  # Then open Terminal window 3, and run the following commands...




### 1. Start CLI Connection
    # drivenet directory has to be next to zcash-sidechain directory
    Main="../drivenet/bin/drivechain-cli -rpcuser=user -rpcpassword=pass -rpcport=18443 "
    zSide="./src/zcash-cli -rpcuser=user -rpcpassword=pass -rpcport=2048 "

    echo "Checking if connection works..."
    $Main getmininginfo
    $zSide getmininginfo



### 2. Start Mainchain + Activate Sidechains

    echo "Starting Mainchain + Activating Sidechains..."

    $Main generate 100
    $Main listactivesidechains
    $Main createsidechainproposal 0 "Zside" "zcash sidechain" "f0d112bd2156dd4d17c1ddb80f15dde4773edcfa72b9dc8465f4f4f1dbbe2ca3"
    $Main listsidechainproposals

    echo "Mining enough blocks to activate the sidechains..."
    $Main generate 255
    $Main listactivesidechains


### 3. Mine Sidechain Blocks

    # mine sidechain blocks
    BMMAMOUNT=0.0001

    function sGenerate(){
      # generates n sidechain blocks (and n mainchain blocks)
      arg1=$1
      echo $arg1
      for ((n=0;n<$arg1;n++))
        do
          $Main generate 1
          $zSide refreshbmm $BMMAMOUNT
          sleep 0.1
          $zSide getmininginfo
        done
       }

    sGenerate 2


### 4. Make Deposit

    # Get Deposit Address
    zSide_dep_address=$( $zSide getnewaddress true )
    echo "Main-to-Side Deposit Address: " $zSide_dep_address_formatted

    # Note: this zCash is programmed to take sidechain slot #0 (the first one)

    echo "depositing to sidechain..."

    $Main createsidechaindeposit 0 $zSide_dep_address 77 0.01

    # Mine enough blocks to mature the deposit.
    sGenerate 7

    # Now we have 77 coins on the sidechain.
    # They should be in one UTXO with about 3 confirmations.
    $zSide listunspent


### 5. Send t-to-t

    # Get a new (2nd) t-address
    st_adr=$( $zSide getnewaddress false )
    echo "New t-Address: " $st_adr

    $zSide sendtoaddress $st_adr 66

    sGenerate 7

    # Check on it
    $zSide listunspent
    echo "Money in t-addr #2: "
    $zSide z_getbalance $st_adr


### 6. Get new shielded address

    sz_adr=$( $zSide z_getnewaddress )
    echo "Shielded zSide Address: " $sz_adr

    $zSide z_listaddresses


### 7. Send transaction to shielded address

    echo "Sending to shielded address: "

    $zSide z_sendmany $st_adr '[{"address": "'$sz_adr'" ,"amount": 22}]'


### 8. Shielding process

    $zSide z_getoperationstatus

    echo "Mining enough blocks for shielding process... "
    sGenerate 7

    $zSide z_getoperationstatus


### 9. Check shielded balance

    echo "Your shielded balance: "
    $zSide z_getbalance $sz_adr
