#!/usr/bin/env bash
set -eu
Main() {
	local kconfigs=(
		--kconfig=kernel.config
	)
	local basepkgs=(
		sys-apps/systemd sys-apps/kbd sys-apps/shadow
		sys-fs/erofs-utils sys-fs/btrfs-progs sys-fs/dosfstools
		app-shells/bash
		sys-apps/coreutils
	)
	local cmdline=(
		--cmdline=consoleblank=60
		--cmdline=rw
		# --cmdline=init=/usr/lib/systemd/systemd
		# --cmdline=systemd.hostname=myhostname
	)

	#
	# build the kernel
	#
	mkdir -p output/{.work,linux}
	Notice build 'building linux'
	Builder "${kconfigs[@]}" linux --workdir=output/.work --root=output/linux --quiet

	#
	# install the bootloader
	#
	mkdir -p output/linux
	Notice build 'installing the bootloader'
	Builder bootloader --root output/linux

	# #
	# # emerge glibc
	# #
	# mkdir -p output/{.work,glibc}
	# Notice build 'building the glibc filesystem'
	# Builder "${kconfigs[@]}" emerge --nproc=16 --jobs=2 --workdir=output/.work --root=output/glibc --confdir=portage-glibc --noreplace sys-apps/baselayout sys-libs/glibc \
	# 	# --pretend; return

	# #
	# # emerge the initramfs filesystem
	# #
	# mkdir -p output/{.work,initramfs}
	# Notice build 'building the initramfs filesystem'
	# Builder "${kconfigs[@]}" emerge --nproc=16 --jobs=2 --workdir=output/.work output/glibc --root=output/initramfs --confdir=portage-glibc --confdir=portage-initramfs --noreplace "${basepkgs[@]}" \
	# 	# --pretend; return

	#
	# build the initramfs cpio
	#
	mkdir -p output/{.work,linux}
	Notice build 'building the initramfs cpio'
	# Builder "${kconfigs[@]}" cpio --workdir=output/.work --root=output/linux --rootpw="${ Builder -- mkpasswd "root"; }" overlay-initramfs output/initramfs #kvm-intel battery
	Builder "${kconfigs[@]}" cpio --workdir=output/.work output/glibc output/initramfs --root=output/linux overlay-initramfs overlay-repart overlay-verity overlay-locality --rootpw=root 

	# #
	# # emerge the root filesystem
	# #
	# mkdir -p output/{.work,osroot}
	# Notice build 'building the root filesystem'
	# Builder "${kconfigs[@]}" emerge --nproc=16 --jobs=2 --workdir=output/.work output/glibc --root=output/osroot --confdir=portage-glibc --confdir=portage-osroot --noreplace "${basepkgs[@]}" \
	# 	# --pretend; return

	# #
	# # emerge the changed use flag packages
	# #
	# mkdir -p output/{.work,newuse}
	# Notice build 'building the changed use flag packages'
	# Builder "${kconfigs[@]}" emerge --nproc=16 --jobs=2 --workdir=output/.work output/glibc output/osroot --root=output/newuse --confdir=portage-glibc --confdir=portage-osroot --confdir=portage-dtroot --newuse sys-auth/polkit \
	# 	# --pretend; return

	#
	# image the root filesystem
	#
	rm -fr output/image-osroot; mkdir -p output/image-osroot
	Notice build 'imaging the root filesystem'
	Builder image --outdir=output/image-osroot --name=osroot --definitions=repart.d-usr output/glibc output/osroot output/linux overlay-osroot overlay-locality overlay-verity overlay-network --private-key=verity.key --certificate=verity.crt

	#
	# build the uki
	#
	mkdir -p output/{.work,linux}
	Notice build 'building the os uki'
	Builder "${kconfigs[@]}" uki --workdir=output/.work --root=output/linux --variant=initramfs "${cmdline[@]}" --cmdline=usrhash="${ jq --raw-output '.[] |select(.type == "usr-x86-64").roothash' output/image-osroot/image.json; }" output/osroot overlay-osroot

	#
	# image the distribution
	#
	rm -fr output/image-dist && mkdir -p output/image-dist
	Notice build 'build the dist image'
	Builder image --outdir=output/image-dist --definitions=repart.d-dist --copy-from=output/image-osroot/image.raw output/linux #--private-key=verity.key --certificate=verity.crt
}
Notice() {
	local -r heading="$1"; shift
	local -r bracketColor=8
	printf "${ tput setaf $bracketColor; }[${ tput sgr0; }${ tput setaf 11; tput bold; }%s${ tput sgr0; }${ tput setaf $bracketColor; }]${ tput sgr0; } %s\n" "$heading" "$*"
}
Builder() {
	volumes=(
		--volume="$HOME"/.var/db/repos:/var/db/repos
		--volume="$HOME"/.cache/binpkgs:/var/cache/binpkgs
		--volume="$HOME"/.cache/distfiles:/var/cache/distfiles
	)
	podman run --rm --interactive --tty --device=/dev/fuse ${volumes[*]} --volume="$PWD":"$PWD" --workdir="$PWD" builder-portage "$@"
}
Main "$@"

# CONFIG_SECURITY_LOADPIN
#	PCI_PWRCTRL_GENERIC
#	EEPROM_AT25
#	disable CFG80211_CRDA_SUPPORT
#
#	brcm/bcm43xx-0.fw
#	brcm/bcm43xx_hdr-0.fw
#
# CONFIG_DEBUG_INFO_BTF:	 is not set when it should be.
# CONFIG_FTRACE_SYSCALLS:	 is not set when it should be.
# CONFIG_KPROBES:	 is not set when it should be.
# CONFIG_KRETPROBES:	 is not set when it should be.
# CONFIG_KPROBE_EVENTS:	 is not set when it should be.
