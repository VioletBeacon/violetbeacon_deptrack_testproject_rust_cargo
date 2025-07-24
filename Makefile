ARTEFACTS := artefacts

# Run each step in a separate invocation so that I can repeatedly call `clean`
.PHONY: all
all:
	make setup
	make clean
	make ${ARTEFACTS}/cargo_lock_list.txt
	make clean
	make build
	make clean
	make cyclonedx-allfeatures
	make clean
	make cyclonedx
	make clean
	make audit
	make clean
	make tree
	make clean

.PHONY: setup
setup:
	mkdir -p ${ARTEFACTS}

${ARTEFACTS}/cargo_lock_list.txt:
	grep '^name = ' Cargo.lock | sed 's/name = "\([^"]*\)"/\1/' | sort | uniq >$@

.PHONY: build
build:
	cargo build 2>&1 | tee ${ARTEFACTS}/build.log
	grep 'Downloaded ' ${ARTEFACTS}/build.log \
		| sed 's/^\s*Downloaded \([^ ].*\) .*/\1/' \
		| sort | uniq >${ARTEFACTS}/build_list.txt

.PHONY: clean
clean:
	cargo cache --remove-dir all
	rm -rf target

.PHONY: cyclonedx-allfeatures
cyclonedx-allfeatures: CDXFILE=cyclonedx-allfeatures.cdx.json
cyclonedx-allfeatures:
	cargo cyclonedx -f json --spec-version 1.5 --all --all-features \
		--target all 2>&1 |tee ${ARTEFACTS}/cyclonedx-allfeatures.log
	mv violetbeacon_deptrack_testproject_rust_cargo.cdx.json ${CDXFILE}
	sed -n 's/^\s*Downloaded \([^ ].*\) .*/\1/p' ${ARTEFACTS}/cyclonedx-allfeatures.log \
		| sort | uniq >${ARTEFACTS}/cyclonedx-allfeatures_downloads.txt
	jq '.["components"][]["name"]' ${CDXFILE} \
		| sed 's/"\([^"]*\)"/\1/' >${ARTEFACTS}/cyclonedx-allfeatures_components.tmp
	jq '.["metadata"]["component"]["name"]' ${CDXFILE} \
		| sed 's/"\([^"]*\)"/\1/' >>${ARTEFACTS}/cyclonedx-allfeatures_components.tmp
	cat ${ARTEFACTS}/cyclonedx-allfeatures_components.tmp | sort | uniq >${ARTEFACTS}/cyclonedx-allfeatures_components.txt
	rm ${ARTEFACTS}/cyclonedx-allfeatures_components.tmp

.PHONY: cyclonedx
cyclonedx: CDXFILE=cyclonedx.cdx.json
cyclonedx:
	cargo cyclonedx -f json --spec-version 1.5 --all --target all 2>&1 |tee ${ARTEFACTS}/cyclonedx.log
	mv violetbeacon_deptrack_testproject_rust_cargo.cdx.json ${CDXFILE}
	sed -n 's/^\s*Downloaded \([^ ].*\) .*/\1/p' ${ARTEFACTS}/cyclonedx.log \
		| sort | uniq >${ARTEFACTS}/cyclonedx_downloads.txt
	jq '.["components"][]["name"]' ${CDXFILE} \
		| sed 's/"\([^"]*\)"/\1/' >${ARTEFACTS}/cyclonedx_components.tmp
	jq '.["metadata"]["component"]["name"]' ${CDXFILE} \
		| sed 's/"\([^"]*\)"/\1/' >>${ARTEFACTS}/cyclonedx_components.tmp
	cat ${ARTEFACTS}/cyclonedx_components.tmp | sort | uniq >${ARTEFACTS}/cyclonedx_components.txt
	rm ${ARTEFACTS}/cyclonedx_components.tmp

.PHONY: audit
audit:
	cargo audit --color never 2>&1 | tee ${ARTEFACTS}/audit.log
	sed -n 's/^Crate:\s\+\(.*\)/\1/p' ${ARTEFACTS}/audit.log >${ARTEFACTS}/audit_list.txt

.PHONY: tree
tree:
	cargo tree --color never 2>&1 | tee ${ARTEFACTS}/tree.log
	grep -v -e Download -e Updating -e build-dependencies ${ARTEFACTS}/tree.log \
		| sed -n 's/^[^a-zA-Z]\+\([^ ]\+\).*$//\1/p' | sort | uniq >${ARTEFACTS}/tree_list.txt
