# I2C Master
This unit provides a simple I2C master with an AXI interface. It has four 32bits registers, which are explained below.


## Registers
### i2c_conf0[31:0]
| Bits | Access | Description |
| ------ | ----------- | ------ |
| [31:16] | RW | **Prescaler**: Prescales the SCL clock line. |
| [15:14] | - | **Unused** |
| 13 | R | **Bus busy**: This bit indicates the bus is involved in a transaction. This will be set at start condition and cleared at stop. (to be done) |
| 12 | RW | **EN**: This bit indicates that the core is enabled. (to be done) |
| 11 | R | **Valid reception**: This bit indicates that the data was successfully received and can be read from the core. This bit is cleared every time a start condition is emitted. |
| 10 | R | **Valid transmission**: This bit indicates that the data was successfully sent. This bit is cleared every time a start condition is emitted.|
| 9  | R | **Error**: This bit indicates an error in the communication. |
| 8  | W | **Start**: This bit starts the state machine. It must be cleared after any transmission/reception. |
| [7:1] | W | **Addr**: Address of the slave. |
| 0 | W | **RW**: This bit indicates if it is a read or write operation .|

### i2c_conf1[31:0], i2c_conf2[31:0] and i2c_conf3[31:24]
These bytes are reserved for a write operation, which is capable of sending 9 bytes for each transmission. The i2c_conf1[31:24] byte is the MSB (the slave register address) and the i2c_conf3[31:24] is the less significant byte.

## i2c_conf3[23:0]
| Bits | Access | Description |
| ------ | ----------- | ------ |
| [23:16] | RW | **Data size**: Indicates the number of data bytes to be sent in a write operation (max of 9). |
| [15:8]  | R | **Data received**: Contains the data received from the I2C bus (only 1 byte can be read from the slave).|
| [7:0]   | - | **Unused**  |



