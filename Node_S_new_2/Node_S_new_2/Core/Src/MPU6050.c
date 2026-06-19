#include "MPU6050.h"

// Hàm khởi tạo (Đánh thức cảm biến)
uint8_t MPU6050_Init(I2C_HandleTypeDef *hi2c) {
    uint8_t check;
    uint8_t data;

    // Kiểm tra xem cảm biến có ở đó không (Đọc WHO_AM_I)
    HAL_I2C_Mem_Read(hi2c, MPU6050_ADDR, REG_WHO_AM_I, 1, &check, 1, 1000);

    if (check == 0x68) { // Mặc định WHO_AM_I trả về 0x68
        // MPU6050 khi cấp nguồn sẽ ở chế độ SLEEP.
        // Cần ghi giá trị 0x00 vào thanh ghi PWR_MGMT_1 (0x6B) để đánh thức nó.
        data = 0x00;
        HAL_I2C_Mem_Write(hi2c, MPU6050_ADDR, REG_PWR_MGMT_1, 1, &data, 1, 1000);
        //2g and 250 dps
        HAL_I2C_Mem_Write(hi2c, MPU6050_ADDR, REG_ACCEL_CONFIG, 1, &data, 1, 1000);
        HAL_I2C_Mem_Write(hi2c, MPU6050_ADDR, REG_GYRO_CONFIG, 1, &data, 1, 1000);
        return 0;
    }
    return -1;
}

// Hàm đọc thử WHO_AM_I
uint8_t MPU6050_Read_WhoAmI(I2C_HandleTypeDef *hi2c) {
    uint8_t who_am_i = 0;
    // Đọc 1 byte từ thanh ghi 0x75
    HAL_I2C_Mem_Read(hi2c, MPU6050_ADDR, REG_WHO_AM_I, 1, &who_am_i, 1, 1000);
    return who_am_i;
}

// Hàm đọc toàn bộ trục X, Y, Z
void MPU6050_Read_Accel(I2C_HandleTypeDef *hi2c, MPU6050_Data_t *DataStruct) {
    uint8_t Rec_Data[6];

    // Đọc LIÊN TIẾP 6 bytes bắt đầu từ thanh ghi ACCEL_XOUT_H (0x3B)
    // Nó sẽ tự động đọc 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40
    HAL_I2C_Mem_Read(hi2c, MPU6050_ADDR, REG_ACCEL_XOUT_H, 1, Rec_Data, 6, 1000);

    // Ghép 2 byte 8-bit thành 1 số nguyên có dấu 16-bit (theo đúng tài liệu của bạn)
    // Bit dịch 8 (<< 8) cho byte High, OR (|) với byte Low
    DataStruct->Accel_X = (int16_t)(Rec_Data[0] << 8 | Rec_Data[1]);
    DataStruct->Accel_Y = (int16_t)(Rec_Data[2] << 8 | Rec_Data[3]);
    DataStruct->Accel_Z = (int16_t)(Rec_Data[4] << 8 | Rec_Data[5]);

    HAL_I2C_Mem_Read(hi2c, MPU6050_ADDR, REG_GYRO_XOUT_H, 1, Rec_Data, 6, 1000);
    DataStruct->Gyro_X = (int16_t)(Rec_Data[0] << 8 | Rec_Data[1]);
    DataStruct->Gyro_Y = (int16_t)(Rec_Data[2] << 8 | Rec_Data[3]);
    DataStruct->Gyro_Z = (int16_t)(Rec_Data[4] << 8 | Rec_Data[5]);

}
