#require "LIS3DH.device.lib.nut:2.0.1" 
#require "SPIFlashFileSystem.device.lib.nut:2.0.0"
// Configure hardware
i2c     <- hardware.i2cNM;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Create Accelerometer object
accel <- LIS3DH(i2c, 0x32);
// Allocate memory to the file system
sffs <- SPIFlashFileSystem(0x010000, 0x30000);
sffs.init();

const LIS3DH_TEMP_CFG_REG  = 0x1F;

//*************************************BME 680**********************************
//Registers

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
	
	_i2c = null;
	_addr = null;
	
	
	constructor(i2c, addr = 0x76) {
		_i2c            = i2c;
		_addr           = addr;
		
		_addr = _addr << 1;
		reset();
		// Get the chip ID
		getID();
		//quick_Start();
		temp();
	}
	
	function reset() {
	    local reset = _setReg(RESET, 0xB6)
	    if (reset == 0) {
	        server.log("BME680 RESET initiated.")
	    }
	}
    function getID() {
        _setReg(ID, 0x00)
        local CID = _getReg(ID);
        if (CID == 0x61) {
            server.log ("BME680 chip ID correct. 0x61")
        } else {
            server.log(format("Chip returned incorrect value for ID: %X", CID))
        }
    }
    function quick_Start() {
        //Set Humidity oversampling to 1x by writing 0b001 to osrs_h<2:0>
        _setReg(CTRL_HUM, 0x01);
        //Set temp & pressure oversampling to 2x & 16x by writing 0b010 to osrs_t<2:0> & 0b101 to osrs_p<2:0>
        _setReg(CTRL_MEAS, 0x28);
        
        _setReg(0x64, 0x59); //gas_wait_0<7:0> to 100ms heat up duration
        _setReg(0x5A, 0x00); //res_heat_0
        _setReg(CTRL_GAS_1, 0x00); //nb_conv<3:0> to 0x00
        _setReg(CTRL_GAS_1, 0x08); //
        
        //Set IIR Filter
        _setRegBit(CONFIG, 2, 1)
        
        //change mode from sleep to single forced mode measurement reading
        _setRegBit(CTRL_MEAS, 0, 1);
        imp.sleep(1);
        
        server.log("TEMP_MSB: " + _getReg(0x22));
        server.log("TEMP_LSB: " + _getReg(0x23));
        server.log("TEMP_XLSB: " + _getReg(0x24));
        
        local temp16 = (_getReg(0x22) << 12 | _getReg(0x23 << 4));
        server.log(temp16);
        
    }
        function temp() {
        //Set Humidity oversampling to 1x by writing 0b001 to osrs_h<2:0>
        _setReg(CTRL_HUM, 0x01);
        //Set temp & pressure oversampling to 2x & 16x by writing 0b010 to osrs_t<2:0> & 0b101 to osrs_p<2:0>
        _setReg(CTRL_MEAS, 0x34);
        
        _setReg(0x64, 0x59); //gas_wait_0<7:0> to 100ms heat up duration
        _setReg(0x5A, 0x00); //res_heat_0
        _setReg(CTRL_GAS_1, 0x00); //nb_conv<3:0> to 0x00
        _setReg(CTRL_GAS_1, 0x08); //
        
        //Set IIR Filter
        _setRegBit(CONFIG, 2, 1)
        
        //change mode from sleep to single forced mode measurement reading
        _setRegBit(CTRL_MEAS, 0, 1);
        imp.sleep(1);
        
        server.log("TEMP_MSB: " + _getReg(0x22));
        server.log("TEMP_LSB: " + _getReg(0x23));
        server.log("TEMP_XLSB: " + _getReg(0x24));
        
        local temp16 = (_getReg(0x22) << 7 | _getReg(0x23));
        server.log(temp16);
        
    }
    //-------------------- PRIVATE METHODS --------------------//

    function _getReg(reg) {
        local result = _i2c.read(_addr, reg.tochar(), 1);
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
//***********************End BME 680********************************************


class EnviroNode {
    static version = "1.0.0"
    _wake_pin = null;
    _vbat_pin = null;
    _vbat = 0.0;
    constructor(vbat_pin, wake_pin) {
        _wake_pin = wake_pin;
        _vbat_pin = vbat_pin;
        
        _vbat_pin.configure(ANALOG_IN);
        _wake_pin.configure(DIGITAL_IN_WAKEUP);
        
        //Make sure the wake pin is not being held high by some source or pin
        if (_wake_pin.read() == 1 ) {
            server.log("Error: Wake Pin read is HIGH.")
        }
        
        wakeReason();
        checkVBAT();
        configACCEL();
    }
    function wakeReason() {
        local reasonString = "Unknown"
        switch(hardware.wakereason()) {
          case WAKEREASON_POWER_ON:
          reasonString = "The power was turned on"
          break
          case WAKEREASON_TIMER:
          reasonString = "An event timer fired"
          break
          case WAKEREASON_SW_RESET:
          reasonString = "A software reset took place"
          break
          case WAKEREASON_PIN:
          reasonString = "Pulse detected on Wakeup Pin"
          /*if (accel_int.read()) {
            server.log("Accelerometer triggered wake.");
          } else if (button.read()) {
            server.log("Button triggered wake.");
          }*/
          break
          case WAKEREASON_NEW_SQUIRREL:
          reasonString = "New Squirrel code downloaded"
          break
          case WAKEREASON_SQUIRREL_ERROR:
          reasonString = "Squirrel runtime error"
          break
          case WAKEREASON_NEW_FIRMWARE:
          reasonString = "impOS update"
          break
          case WAKEREASON_SNOOZE:
          reasonString = "A snooze-and-retry event"
        }
        server.log("Reason for waking/reboot: " + reasonString)
        server.log("Firmware version: " + imp.getsoftwareversion());
}
    function checkVBAT() {
        _vbat = (_vbat_pin.read() / 65535.0) * hardware.voltage();
        server.log(format("System voltage: %0.2fV", hardware.voltage()));
        server.log(format("Battery voltage: %0.2fV", _vbat ));
    }
    
    function configACCEL() {
        accel.setDataRate(100);
        accel.getAccel(function(val) {
            server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", val.x, val.y, val.z));
        });
    }
    
}
node    <- EnviroNode(hardware.pinL, hardware.pinW);
bm3680 <- BME680(i2c);