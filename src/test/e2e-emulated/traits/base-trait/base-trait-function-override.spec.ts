import { toNano } from "@ton/core";
import type { SandboxContract, TreasuryContract } from "@ton/sandbox";
import { Blockchain } from "@ton/sandbox";
import { BaseTraitsFunctionContract } from "./output/base-trait-function-override_BaseTraitsFunctionContract";
import "@ton/test-utils";

describe("base-trait-function-override", () => {
    let blockchain: Blockchain;
    let treasury: SandboxContract<TreasuryContract>;
    let contract: SandboxContract<BaseTraitsFunctionContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        treasury = await blockchain.treasury("treasury");

        contract = blockchain.openContract(
            await BaseTraitsFunctionContract.fromInit(),
        );

        const deployResult = await contract.send(
            treasury.getSender(),
            { value: toNano("10") },
            null,
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: treasury.address,
            to: contract.address,
            success: true,
            deploy: true,
        });
    });

    it("should override function correctly", async () => {
        expect(await contract.getValue()).toEqual(1000n);
    });
});
