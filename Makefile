.PHONY : all
all : check dist

MVN_WORKSPACE           := .maven-workspace
MVN_CACHE               := .maven-cache

# -----------------------------------
TARGET_DIR              := .make-target
MVN_SETTINGS            := settings.xml
MVN_PROPERTIES          := -Dworkspace="$(CURDIR)/$(MVN_WORKSPACE)" \
                           -Dcache="$(CURDIR)/$(MVN_CACHE)" \
                           -Dorg.ops4j.pax.url.mvn.localRepository="$(CURDIR)/$(MVN_WORKSPACE)" \
                           -Dorg.daisy.org.ops4j.pax.url.mvn.settings="$(CURDIR)/settings.xml"
MVN_RELEASE_CACHE_REPO  := $(MVN_CACHE)
GRADLE                  := $(CURDIR)/libs/dotify/dotify.api/gradlew

ifneq ($(MAKECMDGOALS), dump-maven-cmd)
ifneq ($(MAKECMDGOALS), dump-gradle-cmd)
ifneq ($(MAKECMDGOALS), clean-website)
include .make/main.mk
endif
endif
endif

# -----------------------------------

.PHONY : dist
dist: dist-dmg dist-exe dist-zip-linux dist-zip-minimal dist-deb dist-rpm dist-webui-deb dist-webui-rpm

.PHONY : dist-dmg
dist-dmg : assembly/.install-mac.dmg | .maven-init
	cp $(MVN_LOCAL_REPOSITORY)/org/daisy/pipeline/assembly/$(assembly/VERSION)/assembly-$(assembly/VERSION)-mac.dmg \
	   pipeline2-$(assembly/VERSION)_mac.dmg

.PHONY : dist-exe
dist-exe : assembly/.install.exe | .maven-init
	cp $(MVN_LOCAL_REPOSITORY)/org/daisy/pipeline/assembly/$(assembly/VERSION)/assembly-$(assembly/VERSION).exe \
	   pipeline2-$(assembly/VERSION)_windows.exe

.PHONY : dist-zip-linux
dist-zip-linux : assembly/.install-linux.zip | .maven-init
	cp $(MVN_LOCAL_REPOSITORY)/org/daisy/pipeline/assembly/$(assembly/VERSION)/assembly-$(assembly/VERSION)-linux.zip \
	   pipeline2-$(assembly/VERSION)_linux.zip

.PHONY : dist-zip-minimal
dist-zip-minimal : assembly/.dependencies | .maven-init
	cd assembly && \
	$(MVN) clean package -Pminimal | $(MVN_LOG)
	mv assembly/target/*.zip .

.PHONY : dist-deb
dist-deb : assembly/.install-all.deb | .maven-init
	cp $(MVN_LOCAL_REPOSITORY)/org/daisy/pipeline/assembly/$(assembly/VERSION)/assembly-$(assembly/VERSION)-all.deb \
	   pipeline2-$(assembly/VERSION)_debian.deb

.PHONY : dist-rpm
dist-rpm : assembly/.install-rpm.rpm | .maven-init
	cp $(MVN_LOCAL_REPOSITORY)/org/daisy/pipeline/assembly/$(assembly/VERSION)/assembly-$(assembly/VERSION)-rpm.rpm \
	   pipeline2-$(assembly/VERSION)_redhat.rpm

.PHONY : dist-docker-image
dist-docker-image : dist-zip-linux
	cd assembly && \
	$(MAKE) docker

.PHONY : dist-webui-deb
dist-webui-deb : assembly/.dependencies
	# see webui README for instructions on how to make a signed package for distribution
	cd webui && \
	./activator clean debian:packageBin | $(MVN_LOG)
	mv webui/target/*deb .

.PHONY : dist-webui-rpm
dist-webui-rpm : assembly/.dependencies
	# see webui README for instructions on how to make a signed package for distribution
	cd webui && \
	./activator clean rpm:packageBin
	mv webui/target/rpm/RPMS/noarch/*.rpm .

.PHONY : run
run : assembly/target/dev-launcher/bin/pipeline2
	$<

.PHONY : run-gui
run-gui : assembly/target/dev-launcher/bin/pipeline2
	$< gui

.PHONY : run-webui
run-webui : # webui/.dependencies
	if [ ! -d webui/dp2webui ]; then cp -r webui/dp2webui-cleandb webui/dp2webui ; fi
	cd webui && \
	./activator run

.PHONY : run-docker
run-docker : dist-docker-image
	cd assembly && \
	docker run --name pipeline --detach \
	       -e PIPELINE2_WS_HOST=0.0.0.0 \
	       -p 8181:8181 daisyorg/pipeline2

.PHONY : check

.PHONY : release
release : assembly/.release

.PHONY : $(addprefix check-,$(MODULES) $(MAVEN_AGGREGATORS))
$(addprefix check-,$(MODULES) $(MAVEN_AGGREGATORS)) : check-% : %/.last-tested

assembly/target/dev-launcher/bin/pipeline2 : assembly/pom.xml assembly/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init
	cd assembly && \
	$(MVN) clean package -Pdev-launcher | $(MVN_LOG)
	rm assembly/target/dev-launcher/etc/*windows*
	if [ "$$(uname)" == Darwin ]; then \
		rm assembly/target/dev-launcher/etc/*linux*; \
	else \
		rm assembly/target/dev-launcher/etc/*mac*; \
	fi

.SECONDARY : assembly/.install-all.deb
assembly/.install-all.deb : %/.install-all.deb : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,cd assembly && $(MVN) clean install -Pdeb | $(MVN_LOG))))

.SECONDARY : assembly/.install-rpm.rpm
assembly/.install-rpm.rpm : %/.install-rpm.rpm : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,if [ -f /etc/redhat-release ]; then cd assembly && $(MVN) clean install -Prpm | $(MVN_LOG); else echo "Skipping RPM because not running Red Hat/CentOS"; fi)))

.SECONDARY : assembly/.install-linux.zip
assembly/.install-linux.zip : %/.install-linux.zip : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,cd assembly && $(MVN) clean install -Plinux | $(MVN_LOG))))

.SECONDARY : assembly/.install-mac.zip
assembly/.install-mac.zip : %/.install-mac.zip : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,cd assembly && $(MVN) clean install -Pzip-mac | $(MVN_LOG))))

.SECONDARY : assembly/.install-mac.dmg
assembly/.install-mac.dmg : %/.install-mac.dmg : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,cd assembly && $(MVN) clean install -Pmac | $(MVN_LOG))))

.SECONDARY : assembly/.install.exe
assembly/.install.exe : %/.install.exe : %/pom.xml %/.dependencies $(call rwildcard,assembly/src/main/,*) | .maven-init .group-eval
	+$(call eval-if-unix,bash -c $(call quote,$(call quote,cd assembly && $(MVN) clean install -Pwin | $(MVN_LOG))))

.SECONDARY : cli/.install.zip
cli/.install.zip : cli/.install

cli/.install : cli/cli/*.go

.SECONDARY : cli/.install-darwin_386.zip cli/.install-linux_386.zip
cli/.install-darwin_386.zip cli/.install-linux_386.zip : cli/.install

updater/cli/.install : updater/cli/*.go

.SECONDARY : updater/cli/.install-darwin_386.zip updater/cli/.install-linux_386.zip
updater/cli/.install-darwin_386.zip updater/cli/.install-linux_386.zip : updater/cli/.install

.SECONDARY : libs/jstyleparser/.install-sources.jar
libs/jstyleparser/.install-sources.jar : libs/jstyleparser/.install

modules/scripts/dtbook-to-odt/.install-doc.jar : $(call rwildcard,modules/scripts/dtbook-to-odt/src/test/,*)

.SECONDARY : \
	modules/braille/liblouis-utils/liblouis-native/.install-mac.jar \
	modules/braille/liblouis-utils/liblouis-native/.install-linux.jar \
	modules/braille/liblouis-utils/liblouis-native/.install-windows.jar
modules/braille/liblouis-utils/liblouis-native/.install-mac.jar \
modules/braille/liblouis-utils/liblouis-native/.install-linux.jar \
modules/braille/liblouis-utils/liblouis-native/.install-windows.jar: \
	modules/braille/liblouis-utils/liblouis-native/.install

# dotify dependencies

gradle-get-dependency-version = $(shell cat $(1)/build.gradle | perl -ne 'print "$$1\n" if /["'"'"']$(subst .,\.,$(2)):(.+)["'"'"']/')

ifeq ($(call gradle-get-dependency-version,libs/dotify/dotify.formatter.impl,org.daisy.dotify:dotify.api), $(libs/dotify/dotify.api/VERSION))
libs/dotify/dotify.formatter.impl/.dependencies : \
	$(MVN_LOCAL_REPOSITORY)/org/daisy/dotify/dotify.api/$(libs/dotify/dotify.api/VERSION)/dotify.api-$(libs/dotify/dotify.api/VERSION).jar
endif
ifeq ($(call gradle-get-dependency-version,libs/dotify/dotify.formatter.impl,org.daisy.dotify:dotify.common), $(libs/dotify/dotify.common/VERSION))
libs/dotify/dotify.formatter.impl/.dependencies : \
	$(MVN_LOCAL_REPOSITORY)/org/daisy/dotify/dotify.common/$(libs/dotify/dotify.common/VERSION)/dotify.common-$(libs/dotify/dotify.common/VERSION).jar
endif

DOTIFY_MODULES := $(addprefix libs/dotify/dotify.,api common formatter.impl)

eclipse-libs/dotify : $(addsuffix /.project,$(DOTIFY_MODULES)) \
	.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.m2e.core.prefs

# FIXME: every below is needed because `gradle eclipse` does not take into account localRepository from .gradle-settings/conf/settings.xml

$(addsuffix /.project,$(DOTIFY_MODULES)) : %/.project : %/.eclipse-dependencies

.PHONY : $(addsuffix /.eclipse-dependencies,$(DOTIFY_MODULES))
$(addsuffix /.eclipse-dependencies,$(DOTIFY_MODULES)) :

USER_HOME := $(shell echo ~)

ifeq ($(call gradle-get-dependency-version,libs/dotify/dotify.formatter.impl,org.daisy.dotify:dotify.api), $(libs/dotify/dotify.api/VERSION))
$(USER_HOME)/.m2/repository/org/daisy/dotify/dotify.api/$(libs/dotify/dotify.api/VERSION)/dotify.api-$(libs/dotify/dotify.api/VERSION).jar : \
	libs/dotify/dotify.api/build.gradle libs/dotify/dotify.api/gradle.properties $(call rwildcard,libs/dotify/dotify.api/src/,*)
	+$(EVAL) 'bash -c "cd $(dir $<) && ./gradlew install"'
libs/dotify/dotify.formatter.impl/.eclipse-dependencies : \
	$(USER_HOME)/.m2/repository/org/daisy/dotify/dotify.api/$(libs/dotify/dotify.api/VERSION)/dotify.api-$(libs/dotify/dotify.api/VERSION).jar
endif
ifeq ($(call gradle-get-dependency-version,libs/dotify/dotify.formatter.impl,org.daisy.dotify:dotify.common), $(libs/dotify/dotify.common/VERSION))
$(USER_HOME)/.m2/repository/org/daisy/dotify/dotify.common/$(libs/dotify/dotify.common/VERSION)/dotify.common-$(libs/dotify/dotify.common/VERSION).jar : \
	libs/dotify/dotify.common/build.gradle libs/dotify/dotify.common/gradle.properties $(call rwildcard,libs/dotify/dotify.common/src/,*)
	+$(EVAL) 'bash -c "cd $(dir $<) && ./gradlew install"'
libs/dotify/dotify.formatter.impl/.eclipse-dependencies : \
	$(USER_HOME)/.m2/repository/org/daisy/dotify/dotify.common/$(libs/dotify/dotify.common/VERSION)/dotify.common-$(libs/dotify/dotify.common/VERSION).jar
endif

.maven-init : | $(MVN_WORKSPACE)
# the purpose of the test is for making "make -B" not affect this rule (to speed thing up)
$(MVN_WORKSPACE) :
	if ! [ -e $(MVN_WORKSPACE) ]; then \
		mkdir -p $(MVN_CACHE) && \
		cp -r $(MVN_CACHE) $@; \
	fi

.PHONY : cache
cache :
	if [ -e $(MVN_WORKSPACE) ]; then \
		echo "Caching downloaded artifacts..." >&2 && \
		rm -rf $(MVN_CACHE) && \
		rsync -mr --exclude "*-SNAPSHOT" --exclude "maven-metadata-*.xml" $(MVN_WORKSPACE)/ $(MVN_CACHE); \
	fi

clean : cache clean-workspace clean-old clean-website clean-dist clean-webui

.PHONY : clean-workspace
clean-workspace :
	rm -rf $(MVN_WORKSPACE)

.PHONY : clean-dist
clean-dist :
	rm -f *.zip *.deb *.rpm
	rm -rf webui/dp2webui

.PHONY : clean-webui
clean-webui :
	rm -f *.zip *.deb *.rpm
	rm -rf webui/dp2webui

# clean files generated by previous versions of this Makefile
.PHONY : clean-old
clean-old :
	rm -f .maven-modules
	rm -f .effective-pom.xml
	rm -f .gradle-pom.xml
	rm -f .maven-build.mk
	find . -name .deps.mk -exec rm -r "{}" \;
	find . -name .build.mk -exec rm -r "{}" \;
	find * -name .maven-to-install -exec rm -r "{}" \;
	find * -name .maven-to-test -exec rm -r "{}" \;
	find * -name .maven-to-test-dependents -exec rm -r "{}" \;
	find * -name .maven-snapshot-dependencies -exec rm -r "{}" \;
	find * -name .maven-effective-pom.xml -exec rm -r "{}" \;
	find * -name .maven-dependencies-to-install -exec rm -r "{}" \;
	find * -name .maven-dependencies-to-test -exec rm -r "{}" \;
	find * -name .maven-dependencies-to-test-dependents -exec rm -r "{}" \;
	find * -name .gradle-to-test -exec rm -r "{}" \;
	find * -name .gradle-snapshot-dependencies -exec rm -r "{}" \;
	find * -name .gradle-dependencies-to-install -exec rm -r "{}" \;
	find * -name .gradle-dependencies-to-test -exec rm -r "{}" \;

.PHONY : gradle-clean
gradle-clean :
	$(GRADLE) clean

TEMP_REPOS := modules/scripts/dtbook-to-daisy3/target/test/local-repo

.PHONY : go-offline
go-offline :
	if [ -e $(MVN_WORKSPACE) ]; then \
		for repo in $(TEMP_REPOS); do \
			if [ -e $$repo ]; then \
				rsync -mr --exclude "*-SNAPSHOT" --exclude "maven-metadata-*.xml" $$repo/ $(MVN_WORKSPACE); \
			fi \
		done \
	fi

.PHONY : checked
checked :
	touch $(addsuffix /.last-tested,$(MODULES))

website/target/maven/pom.xml : $(addprefix website/src/_data/,modules.yml api.yml versions.yml)
	$(MAKE) -C website target/maven/pom.xml

.PHONY : website
website :
	$(MAKE) -C website

.PHONY : serve-website publish-website clean-website
serve-website publish-website clean-website :
	target=$@ && \
	$(MAKE) -C website $${target%-website}

# this dependency is also defined in website/Makefile, but we need to repeat it here to enable the transitive dependency below
website serve-website publish-website : | $(addprefix website/target/maven/,javadoc doc sources xprocdoc)

$(addprefix website/target/maven/,javadoc doc sources xprocdoc) : website/target/maven/.dependencies
	rm -rf $@
	target=$@ && \
	$(MAKE) -C website $${target#website/}

.PHONY : dump-maven-cmd
dump-maven-cmd :
	echo "mvn () { $(shell dirname "$$(which mvn)")/mvn --settings \"$(CURDIR)/$(MVN_SETTINGS)\" $(MVN_PROPERTIES) \"\$$@\"; }"
	echo '# Run this command to configure your shell: '
	echo '# eval $$(make $@)'

.PHONY : dump-gradle-cmd
dump-gradle-cmd :
	echo M2_HOME=$(CURDIR)/$(SUPER_BUILD_SCRIPT_TARGET_DIR)/.gradle-settings $(GRADLE) $(MVN_PROPERTIES)

.PHONY : help
help :
	echo "make all:"                                                                                                >&2
	echo "	Incrementally compile and test code and package into a DMG, a EXE, a ZIP (for Linux), a DEB and a RPM"  >&2
	echo "make check:"                                                                                              >&2
	echo "	Incrementally compile and test code"                                                                    >&2
	echo "make dist:"                                                                                               >&2
	echo "	Incrementally compile code and package into a DMG, a EXE, a ZIP (for Linux), a DEB and a RPM"           >&2
	echo "make dist-dmg:"                                                                                           >&2
	echo "	Incrementally compile code and package into a DMG"                                                      >&2
	echo "make dist-exe:"                                                                                           >&2
	echo "	Incrementally compile code and package into a EXE"                                                      >&2
	echo "make dist-zip-linux:"                                                                                     >&2
	echo "	Incrementally compile code and package into a ZIP (for Linux)"                                          >&2
	echo "make dist-deb:"                                                                                           >&2
	echo "	Incrementally compile code and package into a DEB"                                                      >&2
	echo "make dist-rpm:"                                                                                           >&2
	echo "	Incrementally compile code and package into a RPM"                                                      >&2
	echo "make dist-webui-deb:"                                                                                     >&2
	echo "	Compile Web UI and package into a DEB"                                                                  >&2
	echo "make dist-webui-rpm:"                                                                                     >&2
	echo "	Compile Web UI and package into a RPM"                                                                  >&2
	echo "make run:"                                                                                                >&2
	echo "	Incrementally compile code and run locally"                                                             >&2
	echo "make run-gui:"                                                                                            >&2
	echo "	Incrementally compile code and run GUI locally"                                                         >&2
	echo "make run-webui:"                                                                                          >&2
	echo "	Compile and run web UI locally"                                                                         >&2
	echo "make website:"                                                                                            >&2
	echo "	Build the website"                                                                                      >&2
	echo "make dump-maven-cmd:"                                                                                     >&2
	echo '	Get the Maven command used. To configure your shell: eval $$(make dump-maven-cmd)'                      >&2

ifndef VERBOSE
.SILENT:
endif
