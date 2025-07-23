ARTEFACTS := artefacts

.PHONY: all
all: setup \
     clean ${ARTEFACTS}/cargo_lock_list.txt \
     clean build \
     clean cyclonedx \
     clean audit \
     clean tree

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

.PHONY:
cyclonedx:
	cargo cyclonedx -f json --spec-version 1.5 --all --all-features \
		--target all 2>&1 |tee ${ARTEFACTS}/cyclonedx.log
	sed -n 's/^\s*Downloaded \([^ ].*\) .*/\1/p' ${ARTEFACTS}/cyclonedx.log \
		| sort | uniq >${ARTEFACTS}/cyclonedx_downloads.txt
	jq '.["components"][]["name"]' violetbeacon_deptrack_testproject_rust_cargo.cdx.json \
		| sed 's/"\([^"]*\)"/\1/' >${ARTEFACTS}/cyclonedx_components.tmp
	jq '.["metadata"]["component"]["name"]' violetbeacon_deptrack_testproject_rust_cargo.cdx.json \
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
