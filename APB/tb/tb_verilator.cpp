#include <verilated.h>
#include <verilated_cov.h>
#include "Vapb_top.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <cstdlib>

class ApbTb {
public:
    Vapb_top* dut;
    vluint64_t sim_time = 0;

    ApbTb() {
        dut = new Vapb_top;
        dut->PCLK = 0;
        dut->PRESETn = 0;
        dut->PSEL = 0;
        dut->PENABLE = 0;
        dut->PWRITE = 0;
        dut->PADDR = 0;
        dut->PWDATA = 0;
    }

    ~ApbTb() {
        delete dut;
    }

    void tick() {
        dut->PCLK = 0;
        dut->eval();
        sim_time += 5;
        dut->PCLK = 1;
        dut->eval();
        sim_time += 5;
    }

    void reset() {
        dut->PRESETn = 0;
        dut->PSEL = 0;
        dut->PENABLE = 0;
        for (int i = 0; i < 5; i++) tick();
        dut->PRESETn = 1;
        tick();
    }

    bool apb_write(uint32_t addr, uint32_t data) {
        // SETUP Phase
        dut->PADDR = addr;
        dut->PWDATA = data;
        dut->PWRITE = 1;
        dut->PSEL = 1;
        dut->PENABLE = 0;
        tick();

        // ACCESS Phase
        dut->PENABLE = 1;
        tick();
        while (!dut->PREADY) {
            tick();
        }

        bool err = dut->PSLVERR;

        // IDLE Phase
        dut->PSEL = 0;
        dut->PENABLE = 0;
        tick();
        return err;
    }

    uint32_t apb_read(uint32_t addr, bool& err) {
        // SETUP Phase
        dut->PADDR = addr;
        dut->PWRITE = 0;
        dut->PSEL = 1;
        dut->PENABLE = 0;
        tick();

        // ACCESS Phase
        dut->PENABLE = 1;
        tick();
        while (!dut->PREADY) {
            tick();
        }

        err = dut->PSLVERR;
        uint32_t rdata = dut->PRDATA;

        // IDLE Phase
        dut->PSEL = 0;
        dut->PENABLE = 0;
        tick();
        return rdata;
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    ApbTb tb;
    bool err = false;
    uint32_t rdata = 0;

    std::cout << "[INFO] Starting Verilator Simulation with Full Coverage Collection..." << std::endl;

    // 1. Initial Reset
    tb.reset();

    // 2. Enable FIFO peripheral (CTRL = 0x1)
    tb.apb_write(0x08, 0x01);
    rdata = tb.apb_read(0x08, err);
    assert((rdata & 0x1) == 0x1);

    // 3. Verify Empty Status & Count = 0
    rdata = tb.apb_read(0x04, err); // STATUS
    assert(rdata & 0x1);           // empty == 1
    rdata = tb.apb_read(0x0C, err); // FIFO_COUNT
    assert(rdata == 0);

    // 4. Test Underflow on Empty FIFO
    rdata = tb.apb_read(0x00, err); // READ from empty FIFO
    assert(err == true);            // PSLVERR expected
    rdata = tb.apb_read(0x04, err); // STATUS
    assert(rdata & 0x8);            // underflow bit set (bit 3)

    // Clear underflow (CTRL[3] = 1, CTRL[0] = 1)
    tb.apb_write(0x08, 0x09);
    tb.apb_write(0x08, 0x01); // restore enable

    // 5. Fill FIFO with 16 entries (Depth 16)
    std::vector<uint32_t> test_patterns;
    for (uint32_t i = 0; i < 16; i++) {
        uint32_t val = 0xAA000000 | (i << 16) | (0x5500) | i;
        test_patterns.push_back(val);
        err = tb.apb_write(0x00, val);
        if (err) {
            std::cout << "[DEBUG] Failed at i=" << i << " rdata status=" << tb.apb_read(0x04, err) << std::endl;
        }
        assert(!err);
    }

    // Verify Full Status & Count = 16
    rdata = tb.apb_read(0x04, err);
    assert(rdata & 0x2);            // full bit set (bit 1)
    rdata = tb.apb_read(0x0C, err);
    assert(rdata == 16);

    // 6. Test Overflow on Full FIFO
    err = tb.apb_write(0x00, 0xDEADBEEF);
    assert(err == true);            // PSLVERR expected on overflow
    rdata = tb.apb_read(0x04, err);
    assert(rdata & 0x4);            // overflow bit set (bit 2)

    // Clear overflow (CTRL[2] = 1, CTRL[0] = 1)
    tb.apb_write(0x08, 0x05);
    tb.apb_write(0x08, 0x01);

    // 7. Drain FIFO completely & verify data match
    for (uint32_t i = 0; i < 16; i++) {
        rdata = tb.apb_read(0x00, err);
        assert(!err);
        assert(rdata == test_patterns[i]);
    }

    // Verify Empty again
    rdata = tb.apb_read(0x04, err);
    assert(rdata & 0x1);

    // 8. Test Flush
    for (uint32_t i = 0; i < 8; i++) {
        tb.apb_write(0x00, 0x11110000 + i);
    }
    rdata = tb.apb_read(0x0C, err);
    assert(rdata == 8);
    // Assert Flush (CTRL[1] = 1, CTRL[0] = 1)
    tb.apb_write(0x08, 0x03);
    tb.apb_write(0x08, 0x01);
    rdata = tb.apb_read(0x0C, err);
    assert(rdata == 0); // count should be 0 after flush
    rdata = tb.apb_read(0x04, err);
    assert(rdata & 0x1); // empty

    // 9. Negative Tests (RO Registers, Unmapped Addresses, Disabled State)
    // Write to STATUS (RO) -> should trigger PSLVERR
    err = tb.apb_write(0x04, 0xFFFFFFFF);
    assert(err == true);

    // Write to FIFO_COUNT (RO) -> should trigger PSLVERR
    err = tb.apb_write(0x0C, 0xFFFFFFFF);
    assert(err == true);

    // Access Unmapped and Unaligned Addresses -> should trigger PSLVERR
    err = tb.apb_write(0x20, 0x12345678);
    assert(err == true);
    tb.apb_read(0x40, err);
    assert(err == true);
    err = tb.apb_write(0xFC, 0xCAFEBABE);
    assert(err == true);

    // Unaligned address attacks (exercising PADDR[0] and PADDR[1])
    err = tb.apb_write(0x01, 0x11111111);
    assert(err == true);
    err = tb.apb_write(0x02, 0x22222222);
    assert(err == true);
    err = tb.apb_write(0x03, 0x33333333);
    assert(err == true);
    tb.apb_read(0x0F, err);
    assert(err == true);

    // Disable FIFO and attempt write/read
    tb.apb_write(0x08, 0x00); // CTRL[0] = 0 (disabled)
    err = tb.apb_write(0x00, 0x99999999);
    assert(err == true); // write while disabled fails
    tb.apb_read(0x00, err);
    assert(err == true); // read while disabled fails

    // Re-enable
    tb.apb_write(0x08, 0x01);

    // 10. Bit-Toggle Sweep & Random Stress Traffic (toggles all 32 data bits 0->1 and 1->0)
    uint32_t bit_patterns[] = {
        0x00000000, 0xFFFFFFFF, 0x55555555, 0xAAAAAAAA,
        0x0F0F0F0F, 0xF0F0F0F0, 0x00FF00FF, 0xFF00FF00,
        0x0000FFFF, 0xFFFF0000, 0x12345678, 0x9ABCDEF0
    };
    for (uint32_t p : bit_patterns) {
        tb.apb_write(0x00, p);
        uint32_t rd = tb.apb_read(0x00, err);
        assert(rd == p);
    }

    // 11. Mid-Traffic Reset Test
    tb.apb_write(0x00, 0xA5A5A5A5);
    // Assert reset mid-traffic
    tb.dut->PRESETn = 0;
    tb.tick();
    tb.tick();
    tb.dut->PRESETn = 1;
    tb.tick();
    // Re-initialize and verify clean state post-reset
    tb.apb_write(0x08, 0x01);
    rdata = tb.apb_read(0x0C, err);
    assert(rdata == 0);

    std::cout << "[SUCCESS] All tests executed successfully!" << std::endl;

    // Save Verilator Coverage Database
    VerilatedCov::write("coverage.dat");
    std::cout << "[INFO] Coverage database saved to coverage.dat" << std::endl;

    return 0;
}
