import { readFileSync } from "fs";
import { run } from "@/cli/tact";
import { Logger, LogLevel } from "@/context/logger";
import * as Stdlib from "@/stdlib/stdlib";
import { createVirtualFileSystem } from "@/vfs/createVirtualFileSystem";
import { join } from "path";
import type { Options } from "@/config/parseConfig";

// helper to reduce boilerplate
export function itShouldNotCompile(params: {
    testName: string;
    errorMessage: string;
}) {
    it(`should not compile ${params.testName}`, async () => {
        const fileName = `${params.testName}.tact`;
        const options: Options = params.testName.includes("external")
            ? {
                  external: true,
              }
            : {};

        const result = await run({
            config: {
                projects: [
                    {
                        name: params.testName,
                        path: `./${fileName}`,
                        output: "./output",
                        options,
                    },
                ],
            },
            logger: new Logger(LogLevel.NONE),
            project: createVirtualFileSystem(
                "/",
                {
                    [fileName]: readFileSync(
                        join(__dirname, "contracts", `./${fileName}`),
                    ).toString("base64"),
                },
                false,
            ),
            stdlib: createVirtualFileSystem("@stdlib", Stdlib.files),
        });

        expect(result.ok).toBe(false);

        const message = result.error.map((err) => err.message).join("; ");
        expect(message).toContain(params.errorMessage);
    });
}
