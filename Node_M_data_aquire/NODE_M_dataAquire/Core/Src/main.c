/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "fatfs.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "state_control.h"
#include "MPU6050.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
I2C_HandleTypeDef hi2c1;

UART_HandleTypeDef hlpuart1;

SPI_HandleTypeDef hspi1;

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_I2C1_Init(void);
static void MX_LPUART1_UART_Init(void);
static void MX_SPI1_Init(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
uint8_t rx_packet[4+6*2+50*2+2];
uint8_t packet_to_file[4+6*2*2+50*2];
static uint16_t sync_cnt = 0;
volatile MPU6050_Data_t MPU_data;
volatile SystemState_t g_system_state = IDLE;
volatile SystemStateInput_t g_system_input;
FATFS FatFs; 	//Fatfs handle
FIL fil_DATA_BIN; 		//File handle
FRESULT fres; //Result after operations

uint16_t calc_crc(uint8_t *data, uint16_t length);
void spi_receive_dummy(uint8_t *rx_buffer, int length);
void spi_send_byte(uint8_t data);
void send_ACK();
void send_NACK();
void uart_send_str(char *s);
void system_init();
void Packetization(uint8_t *rx_packet,
                   volatile MPU6050_Data_t *MPU_data,
                   uint8_t *packet_to_file);
FRESULT Write_Packet(FIL *fil, uint8_t *packet_to_file);
void uart_send_uint32(uint32_t num);
void system_init();
void SD_CARD_init();


/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_LPUART1_UART_Init();
  MX_SPI1_Init();
  MX_FATFS_Init();
  /* USER CODE BEGIN 2 */
  system_init();

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
	  StateControl_ChangeState(&g_system_state, g_system_input);
	  switch(g_system_state)
		  {
		  case IDLE:
		  {
			  g_system_input.RECEIVED_LEN = 0;
			break;
		  }
		  case DATA_AQUIRE:
		  {
			  uart_send_str("DATA_AQUIRE\n");

			             MPU6050_Read_Accel(&hi2c1, &MPU_data);

			             spi_receive_dummy((uint8_t *)rx_packet,
			                               sizeof(rx_packet));

			             g_system_input.RECEIVED_LEN = sizeof(rx_packet);
			             break;
		  }
		  case CHECK_CRC:
		  {
			  uart_send_str("CHECK CRC\n");
			  uint16_t crc =
					  ((uint16_t)rx_packet[117] << 8) |
					   rx_packet[116];
			   uint16_t crc_calc = calc_crc(rx_packet, 116);
			   if (crc == crc_calc)
			   {
				   g_system_input.CRC_TRUE = 1;

			   }
			   else
			   {
				   g_system_input.CRC_FALSE = 1;
			   }
			  break;
		  }
		  case PACKETNIZATION:
		  {
			  uart_send_str("Packetnization\n");
			  Packetization(rx_packet, &MPU_data, packet_to_file);
			  break;
		  }

		  case SEND_ACK:
		  {
			  if(g_system_input.CRC_TRUE)
				  g_system_input.CRC_TRUE = 0;
			  if(g_system_input.INT_FLAG)
				  g_system_input.INT_FLAG = 0;
			  send_ACK();
			  uart_send_str("send ACK\n");

			  break;
		  }
		  case SEND_NACK:
		  {
			  if(g_system_input.CRC_FALSE)
			  				  g_system_input.CRC_FALSE = 0;
			  if(g_system_input.INT_FLAG)
				  g_system_input.INT_FLAG = 0;
			  send_NACK();
			  uart_send_str("send NACK\n");

			  break;
		  }
		  case SD_CARD_WRITE:
		  {
			  uart_send_str("SD_CARD_WRITE\n");

			  fres = Write_Packet(&fil_DATA_BIN,
								  packet_to_file);

			  if(fres != FR_OK)
			  {
				  uart_send_str("write error\n");
			  }

			  sync_cnt++;

			  if(sync_cnt >= 10)
			  {
				  f_sync(&fil_DATA_BIN);
				  sync_cnt = 0;
			  }

			  break;
		  }
		  case FINISH:
		  {
			  uart_send_str("FINISH\n");

			  f_sync(&fil_DATA_BIN);
			  f_close(&fil_DATA_BIN);

			  break;
		  }

		  default:
		  {
			  g_system_state = IDLE;
			  break;
		  }
  }
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
  RCC_PeriphCLKInitTypeDef PeriphClkInit = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLMUL = RCC_PLLMUL_4;
  RCC_OscInitStruct.PLL.PLLDIV = RCC_PLLDIV_2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_1) != HAL_OK)
  {
    Error_Handler();
  }
  PeriphClkInit.PeriphClockSelection = RCC_PERIPHCLK_LPUART1|RCC_PERIPHCLK_I2C1;
  PeriphClkInit.Lpuart1ClockSelection = RCC_LPUART1CLKSOURCE_PCLK1;
  PeriphClkInit.I2c1ClockSelection = RCC_I2C1CLKSOURCE_PCLK1;
  if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief I2C1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2C1_Init(void)
{

  /* USER CODE BEGIN I2C1_Init 0 */

  /* USER CODE END I2C1_Init 0 */

  /* USER CODE BEGIN I2C1_Init 1 */

  /* USER CODE END I2C1_Init 1 */
  hi2c1.Instance = I2C1;
  hi2c1.Init.Timing = 0x00B07CB4;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.OwnAddress2Masks = I2C_OA2_NOMASK;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Analogue filter
  */
  if (HAL_I2CEx_ConfigAnalogFilter(&hi2c1, I2C_ANALOGFILTER_ENABLE) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Digital filter
  */
  if (HAL_I2CEx_ConfigDigitalFilter(&hi2c1, 0) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2C1_Init 2 */

  /* USER CODE END I2C1_Init 2 */

}

/**
  * @brief LPUART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_LPUART1_UART_Init(void)
{

  /* USER CODE BEGIN LPUART1_Init 0 */

  /* USER CODE END LPUART1_Init 0 */

  /* USER CODE BEGIN LPUART1_Init 1 */

  /* USER CODE END LPUART1_Init 1 */
  hlpuart1.Instance = LPUART1;
  hlpuart1.Init.BaudRate = 115200;
  hlpuart1.Init.WordLength = UART_WORDLENGTH_8B;
  hlpuart1.Init.StopBits = UART_STOPBITS_1;
  hlpuart1.Init.Parity = UART_PARITY_NONE;
  hlpuart1.Init.Mode = UART_MODE_TX_RX;
  hlpuart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  hlpuart1.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  hlpuart1.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&hlpuart1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN LPUART1_Init 2 */

  /* USER CODE END LPUART1_Init 2 */

}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_128;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(Slave_CS_GPIO_Port, Slave_CS_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(SD_card_CS_GPIO_Port, SD_card_CS_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin : Slave_CS_Pin */
  GPIO_InitStruct.Pin = Slave_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(Slave_CS_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : SD_card_CS_Pin */
  GPIO_InitStruct.Pin = SD_card_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(SD_card_CS_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : PA8 */
  GPIO_InitStruct.Pin = GPIO_PIN_8;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /* EXTI interrupt init*/
  HAL_NVIC_SetPriority(EXTI4_15_IRQn, 0, 0);
  HAL_NVIC_EnableIRQ(EXTI4_15_IRQn);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
uint16_t calc_crc(uint8_t *data, uint16_t length)
{
    uint16_t crc = 0xFFFF;
    uint16_t i;
    uint8_t j;

    for(i = 0; i < length; i++)
    {
        crc ^= ((uint16_t)data[i] << 8);

        for(j = 0; j < 8; j++)
        {
            if(crc & 0x8000)
            {
                crc = (crc << 1) ^ 0x1021;
            }
            else
            {
                crc <<= 1;
            }
        }
    }

    return crc;
}

void spi_send_byte(uint8_t data)
{
	HAL_GPIO_WritePin(Slave_CS_GPIO_Port, Slave_CS_Pin, GPIO_PIN_RESET);
	HAL_SPI_Transmit(&hspi1,
	                     &data,
	                     1,
	                     HAL_MAX_DELAY);
	HAL_GPIO_WritePin(Slave_CS_GPIO_Port, Slave_CS_Pin, GPIO_PIN_SET);

}

void send_ACK()
{
	spi_send_byte(0xA5);

}

void send_NACK()
{
	spi_send_byte(0x5A);
}

void spi_receive_dummy(uint8_t *rx_buffer, int length)
{
    uint8_t dummy = 0xFF;
    HAL_GPIO_WritePin(Slave_CS_GPIO_Port, Slave_CS_Pin, GPIO_PIN_RESET);
    for(int i = 0; i < length; i++)
    {
        HAL_SPI_TransmitReceive(&hspi1,
                                &dummy,
                                &rx_buffer[i],
                                1,
                                HAL_MAX_DELAY);
    }
    HAL_GPIO_WritePin(Slave_CS_GPIO_Port, Slave_CS_Pin, GPIO_PIN_SET);
}
void uart_send_str(char *s)
{
    while(*s)
    {
        HAL_UART_Transmit(&hlpuart1,
                          (uint8_t*)s,
                          1,
                          HAL_MAX_DELAY);
        s++;
    }
}
void system_init()
{
	MPU6050_Init(&hi2c1);
	__enable_irq();
	StateControl_Init(&g_system_state, &g_system_input);
	SD_CARD_init();
	uart_send_str("init system successfully\n");
}

/*
packet format:

[0:3]     : timestamp (4 byte)
[4:15]    : MPU1 data từ rx_packet
[16:27]   : MPU2 data từ MPU_data
[28:127]  : ECG data (50 * 2 byte)
*/

void Packetization(uint8_t *rx_packet,
                   volatile MPU6050_Data_t *MPU_data,
                   uint8_t *packet_to_file)
{
    uint16_t index = 0;
    uint16_t i;

    // =====================================================
    // 1. Copy timestamp (4 byte)
    // =====================================================
    for(i = 0; i < 4; i++)
    {
        packet_to_file[index++] = rx_packet[i];
    }

    // =====================================================
    // 2. Copy MPU1 data (12 byte)
    //    rx_packet[4 -> 15]
    // =====================================================
    for(i = 0; i < (6 * 2); i++)
    {
        packet_to_file[index++] = rx_packet[4 + i];
    }

    // =====================================================
    // 3. Copy MPU2 data (12 byte)
    // =====================================================

    // Accel_X
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_X >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_X);

    // Accel_Y
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_Y >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_Y);

    // Accel_Z
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_Z >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Accel_Z);

    // Gyro_X
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_X >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_X);

    // Gyro_Y
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_Y >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_Y);

    // Gyro_Z
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_Z >> 8);
    packet_to_file[index++] = (uint8_t)(MPU_data->Gyro_Z);

    // =====================================================
    // 4. Copy ECG data (100 byte)
    //    ECG starts after:
    //    4 byte timestamp + 12 byte MPU1
    // =====================================================
    for(i = 0; i < (50 * 2); i++)
    {
        packet_to_file[index++] = rx_packet[4 + (6 * 2) + i];
    }
}

FRESULT Write_Packet(FIL *fil, uint8_t *packet_to_file)
{
    UINT bytesWritten;
    FRESULT fres;

    fres = f_write(fil,
                   packet_to_file,
                   4 + 6 * 2 * 2 + 50 * 2,
                   &bytesWritten);

    if(fres != FR_OK)
    {
        return fres;
    }

    if(bytesWritten != (4 + 6 * 2 * 2 + 50 * 2))
    {
        return FR_INT_ERR;
    }

    return FR_OK;
}
void SD_CARD_init()
{
	fres = f_mount(&FatFs, "", 1); //1=mount now
	  if (fres != FR_OK) {
		uart_send_str("f_mount error\r\n");
		while(1);
	  }

	  //Let's get some statistics from the SD card
	  DWORD free_clusters, free_sectors, total_sectors;

	  FATFS* getFreeFs;

	  fres = f_getfree("", &free_clusters, &getFreeFs);
	  if (fres != FR_OK) {
		uart_send_str("f_getfree error\r\n");
		while(1);
	  }

	  //Formula comes from ChaN's documentation
	  total_sectors = (getFreeFs->n_fatent - 2) * getFreeFs->csize;
	  free_sectors = free_clusters * getFreeFs->csize;

	  uart_send_str("SD card stats:\r\n");
	  uart_send_uint32(total_sectors / 2);
	  uart_send_str(" KiB total drive space\r\n");
	  uart_send_uint32(free_sectors / 2);
	  uart_send_str(" KiB available\r\n");
	  fres = f_open(&fil_DATA_BIN, "data.bin", FA_WRITE | FA_OPEN_APPEND | FA_OPEN_ALWAYS);

	  if(fres != FR_OK)
	  {
		  while(1);
	  }
	  uart_send_str("open file successfully\n");
}

void uart_send_uint32(uint32_t num)
{
    char buf[11];
    int i = 10;

    buf[i] = '\0';

    if(num == 0)
    {
        HAL_UART_Transmit(&hlpuart1,
                          (uint8_t*)"0",
                          1,
                          HAL_MAX_DELAY);
        return;
    }

    while(num > 0 && i > 0)
    {
        i--;
        buf[i] = (num % 10) + '0';
        num /= 10;
    }

    uart_send_str(&buf[i]);
}
void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
    if (GPIO_Pin == GPIO_PIN_8)
    {
    	g_system_input.INT_FLAG = 1;
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: uart_send_str("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
