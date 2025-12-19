#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_init(void)
{
	pr_info("===== HELLO WORLD MODULE LOADED =====\n");
	pr_info("===== BUILD TIME: %s %s =====\n", __DATE__, __TIME__);
	pr_info("===== TEST: OpenWrt Build Verification =====\n");
	return 0;
}

static void __exit hello_exit(void)
{
	pr_info("===== HELLO WORLD MODULE UNLOADED =====\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Test");
MODULE_DESCRIPTION("Test module to verify build/flash process");
