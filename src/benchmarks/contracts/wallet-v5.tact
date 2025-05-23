/*
    actions

    out_list_empty$_ = OutList 0;
    out_list$_ {n:#} prev:^(OutList n) action:OutAction = OutList (n + 1);
    action_send_msg#0ec3c86d mode:(## 8) out_msg:^(MessageRelaxed Any) = OutAction;

    // Extended actions in W5:
    action_list_basic$_ {n:#} actions:^(OutList n) = ActionList n 0;
    action_list_extended$_ {m:#} {n:#} action:ExtendedAction prev:^(ActionList n m) = ActionList n (m+1);

    action_add_ext#02 addr:MsgAddressInt = ExtendedAction;
    action_delete_ext#03 addr:MsgAddressInt = ExtendedAction;
    action_set_signature_auth_allowed#04 allowed:(## 1) = ExtendedAction;
*/

message(0x7369676E) ExternalSignedRequest {
    walletId: Int as uint32;
    validUntil: Int as uint32;
    seqno: Int as uint32;
    outActions: Cell?;
    hasOtherActions: Bool;
    data: Slice as remaining;
}

// leave as example for discussion
// message(0x73696e74) InternalSignedRequest {
//     data: Slice as remaining;
// }

message(0x73696e74) InternalSignedRequest {
    walletId: Int as uint32;
    validUntil: Int as uint32;
    seqno: Int as uint32;
    outActions: Cell?;
    hasOtherActions: Bool;
    data: Slice as remaining;
}

message(0x6578746e) InternalExtensionRequest {
    queryId: Int as uint64;
    actions: Slice as remaining;
}

asm fun countTrailingZeroes(s: Slice): Int { SDCNTTRAIL0 }
struct SliceFlag {
    data: Slice;
    flag: Bool;
}
asm extends fun beginParseExotic(self: Cell): SliceFlag { XCTOS }
asm extends mutates fun enforceAndRemoveActionSendMsgPrefix(self: Slice) { x{0ec3c86d} SDBEGINS}
asm fun setC5(outActions: Cell) { c5 POP }

asm extends mutates fun checkAndRemoveAddExtensionPrefix(self: Slice): Bool {x{02} SDBEGINSQ}
asm extends mutates fun checkAndRemoveDeleteExtensionPrefix(self: Slice): Bool {x{03} SDBEGINSQ}
asm extends mutates fun checkAndRemoveSetSignAllowedPrefix(self: Slice): Bool {x{04} SDBEGINSQ}

// as example
asm fun typeCast(asd: InternalSignedRequest): ExternalSignedRequest {}

contract WalletV5(
    isSignatureAllowed: Bool,
    seqno: Int as uint32,
    walletId: Int as int32,
    publicKey: Int as uint256,
    extensions: map<Int as uint256, Bool>,
) {
    /*
    actions has the following structure:

    {
        outActions: Cell?;
        hasOtherActions: Bool;
        actions: Slice as remaining; // tl-b for ext actions
    }
    */
    inline fun processActions(actions: Slice, isExternal: Bool, isExtension: Bool) {
        let outActions = actions.loadMaybeRef();
        if (outActions != null) {
            setC5(processSendMessages(outActions!!, isExternal));
        }

        if (!actions.loadBool()) {
            return;
        }

        while (true) {
            // check tag, process action, try to load next ref while we can
            let isAddExt = actions.checkAndRemoveAddExtensionPrefix();
            let isDeleteExt = isAddExt ? false : actions.checkAndRemoveDeleteExtensionPrefix();

            if (isAddExt || isDeleteExt) {
                let addr = parseStdAddress(actions.loadAddress().asSlice());
                let myAddr = parseStdAddress(myAddress().asSlice());

                throwUnless(145, addr.workchain == myAddr.workchain); // force_workchain optimization

                if (isAddExt) {
                    // blocked by https://github.com/tact-lang/tact/issues/2842
                    // throwUnless(139, self.extensions.add(addr.address, true));
                    throwIf(139, self.extensions.exists(addr.address));
                    self.extensions.set(addr.address, true);
                } else if (isDeleteExt) {
                    throwUnless(140, self.extensions.del(addr.address));
                    throwIf(144, self.extensions.isEmpty() && !self.isSignatureAllowed);
                }
            } else if (actions.checkAndRemoveSetSignAllowedPrefix()) {
                throwUnless(146, isExtension);
                let newSignMode = actions.loadBool();
                throwIf(143, newSignMode == self.isSignatureAllowed);
                self.isSignatureAllowed = newSignMode;

                if (!self.isSignatureAllowed && self.extensions.isEmpty()) {
                    throw(142);
                }
            } else {
                throw(141);
            }

            if (actions.refsEmpty()) {
                return;
            }

            actions = actions.preloadRef().beginParse();
        }
    }

    receive(msg: InternalExtensionRequest) {
        let myAddr = parseStdAddress(myAddress().asSlice());
        let addr = parseStdAddress(sender().asSlice());

        // Before signature checking we handle errors silently (return), after signature checking we throw exceptions.
        if (addr.workchain != myAddr.workchain) {
            // throw(0) is idiom to successfully exit current continuation without saving state
            throw(0);
        }
        if (!self.extensions.exists(addr.address)) {
            throw(0);
        }

        self.processActions(msg.actions, false, true);
    }

    receive(msg: InternalSignedRequest) {
        let msgSlice = inMsg();
        let signature = msgSlice.lastBits(512);
        let signedSlice = msgSlice.skipLastBits(512);

        let isSignatureValid = checkSignature(signedSlice.hash(), signature, self.publicKey);
        if (!isSignatureValid) {
            return;
        }

        throwIf(132, !self.isSignatureAllowed && self.extensions.isEmpty());
        throwUnless(133, msg.seqno == self.seqno);
        throwUnless(134, msg.walletId == self.walletId);
        throwIf(136, msg.validUntil <= now());

        self.seqno += 1;
        commit();

        signedSlice.skipBits(32 + 32 + 32 + 32); // skip opcode, walletId, validUntil, seqno
        self.processActions(signedSlice, false, false);
    }

    receive(_: Slice) {
        // Fallback
    }

    external(msg: ExternalSignedRequest) {
        let msgSlice = inMsg();
        let signature = msgSlice.lastBits(512);
        let signedSlice = msgSlice.skipLastBits(512);

        let isSignatureValid = checkSignature(signedSlice.hash(), signature, self.publicKey);
        if (!isSignatureValid) {
            throw(135);
        }

        throwIf(132, !self.isSignatureAllowed && self.extensions.isEmpty());
        throwUnless(133, msg.seqno == self.seqno);
        throwUnless(134, msg.walletId == self.walletId);
        throwIf(136, msg.validUntil <= now());

        acceptMessage();

        self.seqno += 1;
        // NOTE: fix, blocked by #2073
        commit();

        signedSlice.skipBits(32 + 32 + 32 + 32); // skip opcode, walletId, validUntil, seqno
        self.processActions(signedSlice, true, false);
    }

    get fun seqno(): Int {
        return self.seqno;
    }

    get fun get_subwallet_id(): Int {
        return self.walletId;
    }

    get fun get_public_key(): Int {
        return self.publicKey;
    }

    get fun get_extensions(): map<Int as uint256, Bool> {
        return self.extensions;
    }
}

inline fun processSendMessages(outActions: Cell, isExternal: Bool): Cell {
    let cs = outActions.beginParseExotic().data;
    let count = 0;

    while (!cs.empty()) {
        cs.enforceAndRemoveActionSendMsgPrefix();

        throwUnless(147, cs.bits() == 8);
        throwUnless(147, cs.refs() == 2);
        throwIf(137, isExternal && (countTrailingZeroes(cs.preloadBits(7)) > 0));

        cs = cs.preloadRef().beginParseExotic().data;
        count += 1;
    }

    throwUnless(147, count <= 255);
    throwUnless(147, cs.refs() == 0);

    return outActions;
}
