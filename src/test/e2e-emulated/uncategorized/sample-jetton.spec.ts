import { beginCell, toNano } from "@ton/core";
import type { SandboxContract, TreasuryContract } from "@ton/sandbox";
import { Blockchain } from "@ton/sandbox";
import { SampleJetton } from "./output/sample-jetton_SampleJetton";
import { JettonDefaultWallet } from "./output/sample-jetton_JettonDefaultWallet";
import "@ton/test-utils";

describe("bugs", () => {
    let blockchain: Blockchain;
    let treasury: SandboxContract<TreasuryContract>;
    let contract: SandboxContract<SampleJetton>;
    let target: SandboxContract<JettonDefaultWallet>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.verbosity.print = false;
        treasury = await blockchain.treasury("treasury");

        contract = blockchain.openContract(
            await SampleJetton.fromInit(
                treasury.address,
                beginCell().endCell(),
                toNano("100"),
            ),
        );

        target = blockchain.openContract(
            await JettonDefaultWallet.fromInit(
                contract.address,
                treasury.address,
            ),
        );

        const deployResult = await contract.send(
            treasury.getSender(),
            { value: toNano("10") },
            {
                $$type: "Mint",
                receiver: treasury.address,
                amount: toNano("10"),
            },
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: treasury.address,
            to: contract.address,
            success: true,
            deploy: true,
        });
    });

    it("should deploy sample jetton correctly", async () => {
        // Ensure that the Mint operation was successful and the transaction was correct
        const mintResult = await contract.send(
            treasury.getSender(),
            { value: toNano("10") },
            {
                $$type: "Mint",
                receiver: treasury.address,
                amount: toNano("10"),
            },
        );

        expect(mintResult.transactions).toHaveTransaction({
            from: treasury.address,
            to: contract.address,
            success: true,
        });
        expect(mintResult.transactions).toHaveTransaction({
            from: contract.address,
            op: 0x178d4519,
            success: true,
        });
        expect(mintResult.transactions).toHaveTransaction({
            to: treasury.address,
            op: 0xd53276db,
        });

        expect((await target.getGetWalletData()).balance).toBe(toNano("20"));
    });
});
