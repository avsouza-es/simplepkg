#
#  Simplepkg Makefile by Silvio Rhatto (rhatto at riseup.net).
#
#  This Makefile is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the Free
#  Software Foundation; either version 2 of the License, or any later version.
#
#  This Makefile is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along with
#  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
#  Place - Suite 330, Boston, MA 02111-1307, USA
#

PACKAGE = simplepkg
VERSION = $(shell echo '$$Rev$$' | sed -e 's/[^0-9]//g')_svn
BUILD = 1rha
PREFIX = /usr
INSTALL = /usr/bin/install

clean:
	find . -name *~ | xargs rm -f # clean local backups

install_lib:
	$(INSTALL) -D --mode=0644 lib/common.sh $(DESTDIR)/$(PREFIX)/libexec/$(PACKAGE)/common.sh

install_bin:
	$(INSTALL) -D --mode=0755 src/simplaret $(DESTDIR)/$(PREFIX)/bin/simplaret
	$(INSTALL) -D --mode=0755 src/lspkg $(DESTDIR)/$(PREFIX)/bin/lspkg
	$(INSTALL) -D --mode=0755 src/mkbuild $(DESTDIR)/$(PREFIX)/bin/mkbuild
	$(INSTALL) -D --mode=0755 src/mkpatch $(DESTDIR)/$(PREFIX)/bin/mkpatch

install_sbin:
	$(INSTALL) -D --mode=0755 src/mkjail $(DESTDIR)/$(PREFIX)/sbin/mkjail
	$(INSTALL) -D --mode=0755 src/templatepkg $(DESTDIR)/$(PREFIX)/sbin/templatepkg
	$(INSTALL) -D --mode=0755 src/jail-update $(DESTDIR)/$(PREFIX)/sbin/jail-update
	$(INSTALL) -D --mode=0755 src/jail-commit $(DESTDIR)/$(PREFIX)/sbin/jail-commit
	$(INSTALL) -D --mode=0755 src/rebuildpkg $(DESTDIR)/$(PREFIX)/sbin/rebuildpkg
	$(INSTALL) -D --mode=0755 src/createpkg $(DESTDIR)/$(PREFIX)/sbin/createpkg
	$(INSTALL) -D --mode=0755 src/simpletrack $(DESTDIR)/$(PREFIX)/sbin/simpletrack
	@cd $(DESTDIR)/usr/sbin && ln -sf jail-upgrade vserver-upgrade

install_doc:
	$(INSTALL) -D --mode=0644 doc/COPYING $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/COPYING
	$(INSTALL) -D --mode=0644 doc/TODO $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/TODO
	$(INSTALL) -D --mode=0644 doc/CHANGELOG $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/CHANGELOG
	#$(INSTALL) -D --mode=0644 doc/README $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/README
	#$(INSTALL) -D --mode=0644 doc/README.pt_BR $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/README.pt_BR
	#$(INSTALL) -D --mode=0644 doc/README.simplaret $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/README.simplaret
	#$(INSTALL) -D --mode=0644 doc/README.simplaret.pt_BR $(DESTDIR)/$(PREFIX)/doc/$(PACKAGE)-$(VERSION)/README.simplaret.pt_BR

install_config:
	$(INSTALL) -D --mode=0644 conf/$(PACKAGE).conf $(DESTDIR)/etc/$(PACKAGE)/defaults/$(PACKAGE).conf
	$(INSTALL) -D --mode=0644 conf/repos.conf $(DESTDIR)/etc/$(PACKAGE)/defaults/repos.conf
	@mkdir -p $(DESTDIR)/etc/$(PACKAGE)/defaults/mkbuild/
	@cp mkbuild/* $(DESTDIR)/etc/$(PACKAGE)/defaults/mkbuild/

install_defaults:
	@mkdir -p $(DESTDIR)/etc/$(PACKAGE)/{defaults/mkbuild,templates}
	@rsync -av --exclude=.svn templates/* $(DESTDIR)/etc/$(PACKAGE)/defaults/templates/
	@chmod +x $(DESTDIR)/etc/$(PACKAGE)/defaults/templates/vserver/scripts/*.sh
	@chmod +x $(DESTDIR)/etc/$(PACKAGE)/defaults/templates/vserver-legacy/scripts/*.sh

install: clean
	@make install_lib install_bin install_sbin install_doc install_config install_defaults
	$(INSTALL) -D --mode=0644 install/slack-desc $(DESTDIR)/install/slack-desc
	#$(INSTALL) -D --mode=0755 install/doinst.sh $(DESTDIR)/install/doinst.sh

package:
	echo "Remember to run this option as root!"
	@rm -rf /tmp/package-$(PACKAGE)
	@mkdir -p /tmp/package-$(PACKAGE)
	@make DESTDIR=/tmp/package-$(PACKAGE) install
	@cd /tmp/package-$(PACKAGE) && makepkg -c y -l y /tmp/$(PACKAGE)-$(VERSION)-noarch-$(BUILD).tgz && cd - && rm -rf /tmp/package-$(PACKAGE)
