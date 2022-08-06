import qbs
import qbs.FileInfo
import "lld_helpers.js" as LLD

Project {

    //Covers most of families but not all
    property string MCU_FAMILY: {
        if (project.MCU.startsWith("STM32")) {
            return project.MCU.substring(0, 7) + "xx"
        }
        else {
            console.error("Target MCU is not supported by QBS")
        }
    }

    StaticLibrary {
        name: "chibios"

        Export {
            Depends { name: 'cpp' }
            Depends { name: 'os_common' }
            Depends { name: 'config' }
            Depends { name: 'hal' }

            cpp.includePaths: [
                project.CH_PATH + "os/rt/include",
                project.CH_PATH + "os/oslib/include"
            ]

            Group {
                name: "rt"
                prefix: project.CH_PATH + "/os/rt/"
                files: [
                    "src/*.c",
                    "include/*.h"
                ]
            }

            Group {
                name: "oslib"
                prefix: project.CH_PATH + "os/oslib/"
                files: [
                    "src/*.c",
                    "include/*.h"
                ]
            }
            Group {
                name: "various"
                prefix: project.CH_PATH + "/os/various/"
                files: [
                    "syscalls.c"
                ]
            }
        }
    }

    Product {
        name: "hal"

        Depends { name: 'cpp' }

        property string halPath: FileInfo.joinPaths(project.sourceDirectory, "ChibiOS/os/hal/")
        property string portPath: "ports/STM32"
        property pathList lldPaths: lldGetter.paths

        property pathList includePaths: [
            "src",
            "include",
            "ports/common/ARMCMx",
            "ports/STM32/" + project.MCU_FAMILY,
            "ports/STM32/LLD/USART",
            "osal/rt-nil"
        ].map(function(path){ return FileInfo.joinPaths(halPath, path) })
        .concat(lldPaths)

        Export {
            Depends { name: 'cpp' }
            cpp.includePaths: exportingProduct.includePaths
        }

        cpp.includePaths: includePaths

        Group {
            name: "drivers"
            prefix: halPath
            files: [
                "include/hal*.h",
                "src/hal*.c"
            ]
        }

        Group {
            name: "port lld"
            prefix: portPath + "/LLD/"
            files: lldGetter.files
        }

        Group {
            name: "port common"
            prefix: FileInfo.joinPaths(halPath, "ports/common/ARMCMx/")
            files: [
                "nvic.c"
            ]

        }

        Group {
            name: "port"
            prefix: FileInfo.joinPaths(halPath, "ports/STM32", project.MCU_FAMILY, "/")
            files: [
                "*.h",
                "hal*.c",
                "stm32_isr.c"
            ]
        }

        Group {
            name: "osal"
            prefix: FileInfo.joinPaths(halPath, "osal/rt-nil/")
            files: [
                "*.h",
                "*.c"
            ]
        }

        Probe {
            id: lldGetter
            property string basePath: FileInfo.joinPaths(halPath, "ports/STM32")
            property string mcuFamily: project.MCU_FAMILY
            property pathList paths
            property stringList files
            configure: {
                drivers = LLD.getDriverList(basePath, mcuFamily)
                paths = drivers.map(function(driver) { return FileInfo.joinPaths(basePath + "/LLD", driver) })
                var f = []
                drivers.forEach(function(driver) {
                    if(driver.startsWith("SPI")) {
                        f.push(driver + "/*v2*.h")
                        f.push(driver + "/*v2*.c")
                    }
                    else {
                        f.push(driver + "/*.h")
                        f.push(driver + "/*.c")
                    }
                })
                files = f
                found = true;
            }
        }

    }

    Product {
        name: "os_common"

        property string commonPath: FileInfo.joinPaths(project.sourceDirectory, "ChibiOS/os/common/")
        property string LD_SCRIPTS_PATH: FileInfo.joinPaths(commonPath, "startup/ARMCMx/compilers/GCC/ld/")

        property string ARCH: {
            switch (project.CORE) {
            case "cortex-m3":
            case "cortex-m4":
                return "ARMv7-M"
            case "cortex-m0":
                return "ARMv6-M"
            }
        }

        property string STARTUP_ASM_SRC: {
            switch (ARCH) {
            case "ARMv7-M":
                return "crt0_v7m.S"
            case "ARMv6-M":
                return "crt0_v6m.S"
            }
        }

        Export {
            Depends { name: "cpp" }
            Depends { name: "config" }
            Depends { name: "license" }

            cpp.libraryPaths: [
                exportingProduct.LD_SCRIPTS_PATH
            ]

            cpp.includePaths: [
                "portability/GCC",
                "startup/ARMCMx/compilers/GCC",
                "startup/ARMCMx/devices/" + exportingProduct.MCU_FAMILY,
                "ext/ARM/CMSIS/Core/Include",
                "ext/ST/" + exportingProduct.MCU_FAMILY,
                "ports/ARM-common",
                "ports/" + exportingProduct.ARCH
            ]

        }

        Depends { name: "cpp" }
        Depends { name: "config" }
        Depends { name: "license" }

        cpp.includePaths: [
            "portability/GCC",
            "startup/ARMCMx/compilers/GCC",
            "startup/ARMCMx/devices/" + MCU_FAMILY,
            "ext/ARM/CMSIS/Core/Include",
            "ext/ST/" + MCU_FAMILY,
            "ports/ARM-common",
            "ports/" + ARCH
        ]

        Group {
            name: "startup_device"
            prefix: FileInfo.joinPaths(commonPath, "startup/ARMCMx/devices/", project.MCU_FAMILY, "/")
            files: [
                "cmparams.h"
            ]
        }

        Group {
            name: "startup_src"
            prefix: FileInfo.joinPaths(commonPath, "startup/ARMCMx/compilers/GCC/")
            files: [
                "crt1.c",
                "vectors.S",
                STARTUP_ASM_SRC
            ]
        }

        Group {
            name: "arch specific"
            prefix: FileInfo.joinPaths(commonPath, "ports", ARCH,"/")
            files: [
                "compilers/GCC/chcoreasm.S",
                "chcore.c",
                "chcore.h"
            ]
        }

        Group {
            name: "common"
            prefix: commonPath
            files: [
                "ports/ARM-common/chtypes.h",
                "portability/GCC/ccportab.h"
            ]
        }

        Group {
            name: "Linker files"
            prefix: LD_SCRIPTS_PATH
            fileTags: ["linkerscript"]
            files: [ project.MCU + ".ld"]
        }
    }

    Product {
        name: "license"
        property string licensePath: FileInfo.joinPaths(project.sourceDirectory, "ChibiOS/os/license/")

        Export {
            Depends { name: "cpp" }
            cpp.includePaths: exportingProduct.licensePath
        }

        files: [
            "*.h"
        ]
    }

} //Project end
