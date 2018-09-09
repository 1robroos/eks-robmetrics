data "template_file" "user_data" {
    template = "${file("user_data.tpl")}"
    vars {
        efs_dns_name = "${var.my_efs_fs_name}"
    }
}
