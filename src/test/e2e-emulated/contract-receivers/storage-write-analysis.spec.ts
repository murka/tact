import { toNano } from "@ton/core";
import type { SandboxContract, TreasuryContract } from "@ton/sandbox";
import { Blockchain } from "@ton/sandbox";
import { Tester } from "./output/storage-write-analysis_Tester";
import "@ton/test-utils";

describe("storage-write-analysis", () => {
    let blockchain: Blockchain;
    let treasury: SandboxContract<TreasuryContract>;
    let contract: SandboxContract<Tester>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.verbosity.print = false;
        treasury = await blockchain.treasury("treasury");

        contract = blockchain.openContract(await Tester.fromInit());

        const deployResult = await contract.send(
            treasury.getSender(),
            { value: toNano("1") },
            null,
        );
        expect(deployResult.transactions).toHaveTransaction({
            from: treasury.address,
            to: contract.address,
            actionResultCode: 0,
            success: true,
            deploy: true,
        });
        expect(deployResult.transactions).toHaveTransaction({
            from: contract.address,
            to: contract.address,
            success: true,
        });
        expect(deployResult.transactions.length).toStrictEqual(1 + 1 + 1); // wallet + deploy + one message back to self in init
    });

    it("should persist contract storage when init is called before the empty receiver", async () => {
        // the deployment has the test
    });
});
