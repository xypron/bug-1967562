export PDELIM=oNUAeC0crgus

.PHONY: tftp grub run

all: tftp grub run

jammy-live-server-arm64.iso:
	wget https://cdimage.ubuntu.com/ubuntu-server/daily-live/current/jammy-live-server-arm64.iso

tftp: jammy-live-server-arm64.iso
	mkdir -p mnt/
	mkdir -p tftp/
	mkdir -p tftp/grub/
	mkdir -p tftp/casper/
	sudo kpartx -a -v -p $(PDELIM) jammy-live-server-arm64.iso
	sudo mount  /dev/mapper/loop*$(PDELIM)1 mnt/
	cp mnt/casper/vmlinuz tftp/casper/
	cp mnt/casper/initrd tftp/casper/
	chmod u+w tftp/ -R
	sudo umount mnt/
	sleep 3
	sudo kpartx -d -v jammy-live-server-arm64.iso

grub-efi-arm64-signed.deb:
	wget https://launchpad.net/ubuntu/+archive/primary/+files/grub-efi-arm64-signed_1.179+2.06-2ubuntu6_arm64.deb
	mv grub-efi-arm64-signed_1.179+2.06-2ubuntu6_arm64.deb grub-efi-arm64-signed.deb

grub: grub-efi-arm64-signed.deb
	mkdir -p tftp/grub
	rm -rf deb/
	dpkg -x grub-efi-arm64-signed.deb deb/
	cp deb/usr/lib/grub/arm64-efi-signed/grubnetaa64.efi.signed tftp/grub
	cp grub.cfg tftp/grub

run:
	rm -f disk
	dd if=/dev/zero bs=1M of=disk count=1 seek=8191
	/usr/bin/qemu-system-aarch64 \
	-M virt -accel tcg -m 4096 -smp 4 -cpu max -gdb tcp::1234 \
	-nographic \
	-device qemu-xhci \
	-device usb-kbd \
	-drive file=disk,if=virtio,format=raw \
	-drive if=pflash,format=raw,unit=0,file=/usr/share/AAVMF/AAVMF_CODE.fd,readonly=on \
	-drive file=jammy-live-server-arm64.iso,format=raw,readonly=on,if=none,id=cdrom \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-device virtio-net-device,netdev=net0 \
        -netdev user,hostfwd=tcp::10022-:22,id=net0,tftp=tftp,bootfile=grub/grubnetaa64.efi.signed
