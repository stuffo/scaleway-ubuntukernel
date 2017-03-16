prefix = /usr

install: ubuntukernel-load.sh
	install -D -m755 ubuntukernel-load.sh $(DESTDIR)$(prefix)/bin/ubuntukernel-load.sh

clean:
	echo "all clean"

.PHONY: install clean
