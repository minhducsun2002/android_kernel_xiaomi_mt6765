ifeq ($(CONFIG_MTK_COMBO_FORCE_BUILD),y)
obj-m += 4.9/
endif

ifeq ($(ARCH), arm)
ccflags-y += -DCONFIG_MET_ARM_32BIT
endif	# ifeq ($(ARCH), arm)

obj-y += met_api.o
