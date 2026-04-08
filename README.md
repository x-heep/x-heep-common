# X-HEEP Common Modules

This repository contains a collection of common SystemVerilog RTL modules designed for use with the [X-HEEP Platform](https://github.com/x-heep) and related projects. It serves as a central hub for useful, basic building blocks developed by the X-HEEP community that can be leveraged across various projects and SoC assemblies.

The goal is to provide simple, reusable, and well-maintained modules—such as bus bridges or adapters—that simplify the process of building and extending your own SoC.

## Currently Included Modules

| Module Name | Path | Description |
| ----------- | ---- | ----------- |
| `xheep_mem_demux` | `hw/mem/xheep_mem_demux.sv` | SRAM-like memory request demultiplexer / adapter. |
| `xheep_obi_splitter` | `hw/obi/xheep_obi_splitter.sv` | OBI (Open Bus Interface) request splitter / adapter. |

## Contributing

Contributions are welcome! If you have developed a module that could benefit other X-HEEP users, please consider contributing it to this repository. When adding new content, please follow these guidelines:

1.  **Directory Organization**: Honor the existing structure. Place RTL modules in `hw/<category>/` and include a corresponding `.core` file for FuseSoC.
2.  **FuseSoC Integration**: Always update or create `.core` files to include any new additions and ensure they are properly linked in `xheep-common-all.core`. Also remember to increment the SemVer number whenever you make changes.
3.  **Documentation**:
    *   Update this `README.md` with a brief description of the new files in the table above.
    *   Thoroughly comment your code to help other users understand and use your module.
4.  **Dependencies**: Ensure that modules are as self-contained as possible. Remove any dependencies on project-specific files that are not part of this repository or the main X-HEEP repositories.
5.  **Coding Style**: Align with the X-HEEP coding standards. You can use the provided `Makefile` targets to format and lint your code:
    ```bash
    make format
    make lint
    ```
6.  **Simplicity**: Focus on providing simple, basic blocks that are generally useful for SoC integration.
