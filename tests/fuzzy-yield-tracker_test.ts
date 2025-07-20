import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Farmer Registration Test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('fuzzy-yield-tracker', 'register-farmer', 
                [types.ascii('Emma Green'), types.ascii('California, USA')], 
                deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Field Registration Test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('fuzzy-yield-tracker', 'register-farmer', 
                [types.ascii('Emma Green'), types.ascii('California, USA')], 
                deployer.address),
            Tx.contractCall('fuzzy-yield-tracker', 'register-field', 
                [types.ascii('Sunflower Valley'), types.uint(50), types.ascii('Rich Loam')], 
                deployer.address)
        ]);

        assertEquals(block.receipts.length, 2);
        block.receipts[1].result.expectOk().expectUint(1);
    }
});