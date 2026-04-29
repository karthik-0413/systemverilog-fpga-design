# Makefile for RISC-V RV32I APB GPIO program

# Toolchain configuration
TOOLCHAIN_PATH = /mnt/c/Users/krmum/ece1195_2026s/riscv_tools/bin
CC = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-gcc
AS = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-as
LD = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-ld
OBJCOPY = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-objcopy
OBJDUMP = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-objdump
SIZE = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-size
READELF = $(TOOLCHAIN_PATH)/riscv32-unknown-elf-readelf

# Directories
SRC_DIR = src
BUILD_DIR = build
OUTPUT_DIR = outputs
INCLUDE_DIR = include

# Compiler flags
CFLAGS = -march=rv32i -mabi=ilp32 -O1 -g -Wall -ffreestanding -nostdlib -fno-builtin -I$(INCLUDE_DIR)
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T linker.ld -nostdlib

# Source files
C_SOURCES = $(SRC_DIR)/main.c
ASM_SOURCES = startup.S
OBJECTS = $(BUILD_DIR)/main.o $(BUILD_DIR)/startup.o

# Target executable
TARGET = $(OUTPUT_DIR)/program.elf

# Default target
all: $(TARGET) disassembly hex sections size

# Create build directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Compile C files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble assembly files
$(BUILD_DIR)/%.o: %.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

# Link the program
$(TARGET): $(OBJECTS) linker.ld | $(OUTPUT_DIR)
	$(LD) $(LDFLAGS) $(OBJECTS) -o $@

# Generate disassembly
disassembly: $(TARGET)
	$(OBJDUMP) -d $(TARGET) > $(OUTPUT_DIR)/disassembly.txt
	$(OBJDUMP) -d -S $(TARGET) > $(OUTPUT_DIR)/disassembly_with_source.txt

# Generate hex for memory loading
hex: $(TARGET)
	$(OBJCOPY) -O ihex $(TARGET) $(OUTPUT_DIR)/program.hex
	$(OBJCOPY) -O verilog --verilog-data-width=4 $(TARGET) $(OUTPUT_DIR)/program.verilog.hex
	hexdump -C $(TARGET) > $(OUTPUT_DIR)/hexdump.txt

# Show detailed program size breakdown
size: $(TARGET)
	@echo "Memory sections (loaded into BRAM):"
	@$(OBJDUMP) -h $(TARGET) | awk '/\.text|\.sbss|\.stack/ {printf "%-10s %s bytes @ %s\n", $$2, strtonum("0x" $$3), $$4}'
	@echo ""
	@$(OBJDUMP) -h $(TARGET) | awk 'BEGIN{text=0; sbss=0; stack=0} /\.text/ {text+=strtonum("0x" $$3)} /\.sbss/ {sbss+=strtonum("0x" $$3)} /\.stack/ {stack+=strtonum("0x" $$3)} END {printf "Total BRAM usage: %d bytes (%.1f%% of 4KB)\n", text+sbss+stack, (text+sbss+stack)/4096*100}'
	@echo ""
	@echo "Traditional size command (for reference):"
	@$(SIZE) $(TARGET)

# Analyze sections for memory map
sections: $(TARGET)
	$(READELF) -S $(TARGET) > $(OUTPUT_DIR)/sections.txt
	$(OBJDUMP) -h $(TARGET) >> $(OUTPUT_DIR)/sections.txt

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR)

# Rebuild everything
rebuild: clean all

# Copy hex and disassembly to sim_apb folder
copy-to-sim-apb: hex disassembly
	cp $(OUTPUT_DIR)/program.verilog.hex ../../riscv_fast/sim_apb/
	cp $(OUTPUT_DIR)/disassembly_with_source.txt ../../riscv_fast/sim_apb/
	@echo "Copied program.verilog.hex and disassembly_with_source.txt to sim_apb/"

# Help target
help:
	@echo "Available targets:"
	@echo "  all             - Build everything (default)"
	@echo "  disassembly     - Generate assembly code (with and without C source)"
	@echo "  hex             - Generate Intel hex, Verilog hex, and hexdump"
	@echo "  sections        - Analyze ELF sections for memory map"
	@echo "  size            - Show program size"
	@echo "  copy-to-sim-apb - Copy verilog.hex and disassembly to sim_apb folder"
	@echo "  clean           - Remove build artifacts"
	@echo "  rebuild         - Clean and build everything"
	@echo "  help            - Show this help"

.PHONY: all disassembly hex sections size copy-to-sim-apb clean rebuild help
