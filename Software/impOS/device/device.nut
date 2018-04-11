i2c     <- hardware.i2cNM;
i2c.configure(CLOCK_SPEED_400_KHZ);

//Registers
const LIS3DH_TEMP_CFG_REG  = 0x1F;
const STATUS				= 0x73;
const RESET					= 0xE0;	
const ID					= 0xD0;
const CONFIG				= 0x75;
const CTRL_MEAS				= 0x74;
const CTRL_HUM				= 0x72;
const CTRL_GAS_1			= 0x71;
const CTRL_GAS_0			= 0x70;
const GAS_WAIT_X			= 0x6D; //...0x64
const RES_WAIT_X			= 0x63; //...0x5A
const IDAC_HEAT_X			= 0x59; //...0x50h
const GAS_R_LSB				= 0x2B; 
const GAS_R_MSB				= 0x2A;
const HUM_LSB				= 0x26;
const HUM_MSB				= 0x25;
const TEMP_XLSB				= 0x24;
const TEMP_LSB				= 0x23;
const TEMP_MSB				= 0x22;
const PRESS_XLSB			= 0x21;
const PRESS_LSB				= 0x20;
const PRESS_MSB				= 0x1F;
const EAS_STATUS_0			= 0x1D;
				
class BME680 {
	static VERSION = "1.0.0"
	
	// I2C information
	_i2c = null;
	_addr = null;
	
	
	constructor(i2c, addr = 0x76) {
		_i2c            = i2c;
		_addr           = addr;
		_addr_read      = 0xEE;
		_addr_write     = 0xEF;
		
		// Get the chip ID
		getID();
	}
	
	function reset() {
	    local reset = _setReg(RESET, "0xB6")
	    if (reset == 0) {
	        server.log("BME680 RESET initiated.")
	    }
	}
    function getID() {
        local ID = _getReg(ID);
        if (ID == "0x61") {
            server.log ("Chip ID correct. /0x61/")
        } else {
            server.log("Chip returned incorrect value for ID: " + ID)
        }
    }
    //-------------------- PRIVATE METHODS --------------------//
	// *****These functions are pasted from the LIS3DH library, and need to be fully adapted to the BME680****

    function _getReg(reg) {
        // Read registers
        // The register address must be sent in write mode (slave address 111011X0).
        local write = _i2c.write(_addr_write, format("%c%c", reg, (val & 0xff)));
        if (write) {
            throw "I2C write error: " + write;
        }        
        //Then either a stop or a repeated start condition must be generated. 
        //After this the slave is addressed in read mode (RW = ‘1’) at address 
        //111011X1,  after  which  the  slave  sends  out  data  from  auto - incremented  register 
        //addresses  until  a  NOACKM  and  stop condition occurs.
        local result = _i2c.read(_addr_read, reg.tochar(), 1);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result[0];
    }

    function _getMultiReg(reg, numBits) {
        // Read entire block with auto-increment
        local result = _i2c.read(_addr, reg.tochar(), numBits);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result;
    }

    function _setReg(reg, val) {
        local result = _i2c.write(_addr, format("%c%c", reg, (val & 0xff)));
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    function _setRegBit(reg, bit, state) {
        local val = _getReg(reg);
        if (state == 0) {
            val = val & ~(0x01 << bit);
        } else {
            val = val | (0x01 << bit);
        }
        return _setReg(reg, val);
    }

    function _dumpRegs() {
        //server.log(format("LIS3DH_CTRL_REG1 0x%02X", _getReg(LIS3DH_CTRL_REG1)));
	}
}

bm3680 <- BME680(i2c);