# X-HEEP Common Modules

This repository contains a collection of common SystemVerilog RTL modules designed for use with the [X-HEEP Platform](https://github.com/x-heep) and related projects. It serves as a central hub for useful, basic building blocks developed by the X-HEEP community that can be leveraged across various projects and SoC assemblies.

The goal is to provide simple, reusable, and well-maintained modules—such as bus bridges or adapters—that simplify the process of building and extending your own SoC.

## Included Modules

| Module Name | Path | Description |
| ----------- | ---- | ----------- |
| `xheep_mem_demux` | `hw/mem/xheep_mem_demux.sv` | SRAM-like memory request demultiplexer / adapter. |
| `xheep_obi_splitter` | `hw/obi/xheep_obi_splitter.sv` | OBI (Open Bus Interface) request splitter / adapter. |
| `xheep_obi_to_reg` | `hw/obi/xheep_obi_to_reg.sv` | OBI to register interface bridge. |
| `xheep_obi_to_sram` | `hw/obi/xheep_obi_to_sram.sv` | OBI to SRAM-like memory bridge. |
| `xheep_obi_cdc` | `hw/obi/xheep_obi_cdc.sv` | OBI clock domain crossing (CDC) module. |
| `xheep_obi_cdc_src` | `hw/obi/xheep_obi_cdc_src.sv` | Source side of the OBI CDC. |
| `xheep_obi_cdc_dst` | `hw/obi/xheep_obi_cdc_dst.sv` | Destination side of the OBI CDC. |

## Utilities

### Register Generator (`reg-generator`)

| Tool | Path | Description |
| ---- | ---- | ----------- |
| `reg-generator` | `util/reg-generator/` | FuseSoC generator wrapping [OpenTitan's `regtool.py`](https://opentitan.org/book/util/reggen/index.html) to automate the generation of control-register infrastructure for hardware peripherals. |

The generator is invoked via FuseSoC's `generate` mechanism (generator name: `regtool`, core: `x-heep:util:reg-generator`). Given an HJSON register description, it produces:

- SystemVerilog RTL (`*_reg_pkg.sv`, `*_reg_top.sv`)
- C register-defines header (`*_regs.h`)
- Markdown register documentation

Optionally, it also renders [Mako](https://www.makotemplates.org/) `.tpl` templates before invoking `regtool` and can call a user-provided structs generator to emit a typed C structs header. See [`util/reg-generator/reg-generator.md`](util/reg-generator/reg-generator.md) for full usage and parameter documentation.

## FuseSoC Integration

This repository supports integration in parent projects through [FuseSoC](https://github.com/olofk/fusesoc), a package manager and build abstraction tool for HDL code. Each category of modules provides its own `.core` file, allowing users to import only the necessary components as dependencies in their projects:

*   **`xheep:common:mem`**: Includes memory-related modules like `xheep_mem_demux`.
*   **`xheep:common:obi`**: Includes OBI-related modules like splitters, bridges, and CDC.
*   **`xheep:common:all`**: A top-level core that aggregates all modules above in the repository.
*   **`xheep:util:reg-generator`**: The register generator utility; add as a dependency to any peripheral core that uses the `regtool` generator.

These FuseSoC cores automatically handle dependencies (such as `pulp-platform.org::common_cells`) and include pre-configured Verilator waivers to ensure a smooth, lint-free integration into your flow.

## Contributing

Contributions are welcome! If you have developed a module that could benefit other X-HEEP users, please consider contributing it to this repository. When adding new content, please follow these guidelines:

1.  **Directory Organization**: Honor the existing structure. Place RTL modules in `hw/<category>/` and include a corresponding `.core` file for FuseSoC.
2.  **FuseSoC Integration**: Always update or create `.core` files to include any new additions and ensure they are properly linked in `xheep-common-all.core`. Also remember to increment the SemVer number whenever you make changes.
3.  **Documentation**:
    *   Update this `README.md` with a brief description of the new files in the table above.
    *   Thoroughly comment your code to help other users understand and use your module.
4.  **Dependencies**: Ensure that modules are as self-contained as possible. Remove any dependencies on project-specific files that are not part of this repository or the main X-HEEP repositories.
5.  **Simplicity**: Focus on providing simple, basic blocks that are generally useful for SoC integration.
6.  **Coding Style**: Align with the X-HEEP coding standards. You can use the provided `Makefile` targets to format and lint your code:
    ```bash
    make format
    make lint
    ```
7.  **Continuous Integration**: This repository uses GitHub Actions for CI. Every pull request and push to the `main` branch triggers an automated workflow that runs linting and formatting checks. Ensure your code passes these checks by running the commands above locally.
