/*
 * Copyright (c) 2015-2017 MICROTRUST Incorporated
 * All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 */

#ifndef TEEI_FP_H
#define TEEI_FP_H

enum {
	TEEI_FP_NONE = 0,
	TEEI_FP_VENDOR_FPC,
	TEEI_FP_VEMDOR_GOODIX,
	TEEI_FP_MAX
};

extern unsigned long fp_buff_addr;
extern struct TEEC_UUID uuid_fp;

unsigned long create_fp_fdrv(int buff_size);

#endif  /* end of TEEI_FP_H */
