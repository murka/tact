// not reusing previously used 136 and 137 exit codes
// because Tact reserves the codes from 128 to 255
// and now this is user-land checks 
const InvalidAddressExitCode: Int = 1136;
const MasterchainNotEnabled: Int = 1137;

fun verifyAddress(addr: Address, enabledMasterChain: Bool) {
    let addrSlice = addr.asSlice();
    throwUnless(InvalidAddressExitCode, addrSlice.bits() == 267);
    let h = addrSlice.preloadUint(11);
    if (enabledMasterChain) {
        throwUnless(InvalidAddressExitCode, (h == 1024) || (h == 1279));
    } else {
        throwIf(MasterchainNotEnabled, h == 1279);
        throwUnless(InvalidAddressExitCode, h == 1024);
    }
}

contract MasterchainTester {

    init() {
        
    }
    
    receive("DeployToWorkchain") {
        verifyAddress(sender(), false);
    }

    receive("DeployToMasterchain") {
        verifyAddress(sender(), true);
    }
}
