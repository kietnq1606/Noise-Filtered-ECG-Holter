#ifndef MPU6050_H_
#define MPU6050_H_

#include "stm32l0xx_hal.h" // Thư viện HAL cho STM32L0

// 1. Định nghĩa địa chỉ I2C của cảm biến (Dịch trái 1 bit)
#define MPU6050_ADDR        (0x68 << 1)

// 2. Định nghĩa các thanh ghi (Dựa trên ảnh của bạn)
#define REG_WHO_AM_I        0x75
#define REG_PWR_MGMT_1      0x6B  // Thanh ghi quản lý nguồn (Rất quan trọng để đánh thức chip)

#define REG_ACCEL_CONFIG 	0x1C
#define REG_GYRO_CONFIG		0x1B

#define REG_ACCEL_XOUT_H    0x3B
#define REG_ACCEL_XOUT_L    0x3C
#define REG_ACCEL_YOUT_H    0x3D
#define REG_ACCEL_YOUT_L    0x3E
#define REG_ACCEL_ZOUT_H    0x3F
#define REG_ACCEL_ZOUT_L    0x40

#define REG_GYRO_XOUT_H     0x43
#define REG_GYRO_XOUT_L     0x44
#define REG_GYRO_YOUT_H     0x45
#define REG_GYRO_YOUT_L     0x46
#define REG_GYRO_ZOUT_H     0x47
#define REG_GYRO_ZOUT_L     0x48

// Struct lưu dữ liệu MPU6050
typedef struct {
    int16_t Accel_X;
    int16_t Accel_Y;
    int16_t Accel_Z;

    int16_t Gyro_X;
    int16_t Gyro_Y;
    int16_t Gyro_Z;

} MPU6050_Data_t;

// 4. Khai báo các hàm giao tiếp
uint8_t MPU6050_Init(I2C_HandleTypeDef *hi2c);
uint8_t MPU6050_Read_WhoAmI(I2C_HandleTypeDef *hi2c);
void MPU6050_Read_Accel(I2C_HandleTypeDef *hi2c, MPU6050_Data_t *DataStruct);

#endif /* MPU6050_H_ */
