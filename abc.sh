#!/bin/bash -xe
# for livecd gentoo  install-amd64-minimal-20181223T214502Z.iso
# Create kernel and initrd files from a Gentoo LiveCD (DVD?) for PXE boot.

print-usage() {
  echo "Usage: $0 <output-dir> <gentoo-iso>" >&2
}

# Example Invocation
# sudo ./gen-pxe-initrd-kernel pxe-boot-files ~/Downloads/install-amd64-minimal-20171228T214501Z.iso

outdir="$1"
image="$2"
tmp="$outdir/tmp"

if [ $(id -u) -ne "0" ]; then
  echo "You must run as root or with sudo. This is necessary for the loop mount" && 
  print-usage &&
  exit 2
fi

test -z "$outdir" -o -z "$image" && print-usage && exit 1
test -e "$tmp" && echo "Temporary path '$tmp' already exists." >&2 && exit 1

iso="$tmp/iso"
initrd="$tmp/initrd.dir"

# prepare directories
mkdir -p "$outdir" "$tmp" "$iso" "$initrd/mnt/cdrom"

# extract files from ISO image
mount -o ro,loop "$image" "$iso"
cp "$iso"/{image.squashfs,isolinux/gentoo,isolinux/gentoo.igz} "$tmp"
umount "$iso"

# patch initramfs and add squashfs to it
xz -dc "$tmp/gentoo.igz" | ( cd "$initrd" && cpio -idv )
patch -d "$initrd" -p0 <<'EOF'
--- init.orgi	2018-12-25 09:42:25.625884155 +0000
+++ init	2018-12-25 09:41:58.958675960 +0000
@@ -491,9 +491,9 @@
 		CHROOT=${NEW_ROOT}
 	fi

-	if [ /dev/nfs != "$REAL_ROOT" ] && [ sgimips != "$LOOPTYPE" ] && [ 1 != "$aufs" ] && [ 1 != "$overlayfs" ]; then
-		bootstrapCD
-	fi
+#	if [ /dev/nfs != "$REAL_ROOT" ] && [ sgimips != "$LOOPTYPE" ] && [ 1 != "$aufs" ] && [ 1 != "$overlayfs" ]; then
+#		bootstrapCD
+#	fi

 	if [ "${REAL_ROOT}" = '' ]
 	then
@@ -636,7 +636,7 @@
 		else
 			bad_msg "Block device ${REAL_ROOT} is not a valid root device..."
 			REAL_ROOT=""
-			got_good_root=0
+			got_good_root=1
 		fi
 	done

@@ -718,7 +718,7 @@
 	[ -z "${LOOP}" ] && find_loop
 	[ -z "${LOOPTYPE}" ] && find_looptype

-	cache_cd_contents
+	#cache_cd_contents

 	# If encrypted, find key and mount, otherwise mount as usual
 	if [ -n "${CRYPT_ROOT}" ]
EOF
cp "$tmp/image.squashfs" "$initrd/mnt/cdrom"
( cd "$initrd" && find . -print | cpio -o -H newc | gzip -9 -c - ) > "$tmp/initramfs.gz"

mv "$tmp"/{gentoo,initramfs.gz} "$outdir"
cp ${outdir}/{gentoo,initramfs.gz} /var/lib/tftpboot/
rm -rf "$tmp"
