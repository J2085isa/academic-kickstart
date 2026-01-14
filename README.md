<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flujo de Trabajo - Build and Test For PR</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            line-height: 1.6;
            background-color: #f8f9fa;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 25px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #3498db;
            margin-top: 30px;
        }
        h3 {
            color: #2980b9;
            margin-top: 20px;
        }
        .env-vars, .job-details {
            background-color: #f1f3f5;
            padding: 15px;
            border-radius: 6px;
            margin: 10px 0;
            overflow-x: auto;
        }
        code {
            font-family: Consolas, monospace;
            color: #e74c3c;
            background-color: #f8f9fa;
            padding: 2px 5px;
            border-radius: 4px;
        }
        pre {
            background-color: #f1f3f5;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            border-left: 4px solid #3498db;
        }
        ul {
            list-style-type: disc;
            margin-left: 20px;
        }
        .correction-note {
            background-color: #fff3cd;
            padding: 12px;
            border-radius: 6px;
            border-left: 4px solid #ffc107;
            margin: 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Flujo de Trabajo Unificado: "Build and Test For PR"</h1>
        <p><strong>Descripción:</strong> Flujo de trabajo completo para verificación, construcción y prueba de código en Apache Dubbo, con correcciones aplicadas para funcionamiento adecuado.</p>

        <h2>Configuración General</h2>
        <h3>Disparadores y Permisos</h3>
        <pre>
name: "Build and Test For PR"

on: [push, pull_request, workflow_dispatch]

permissions:
  contents: read</pre>

        <h3>Variables de Entorno</h3>
        <div class="env-vars">
            <code>FORKS_COUNT: 2</code><br>
            <code>FAIL_FAST: 0</code><br>
            <code>SHOW_ERROR_DETAIL: 1</code><br>
            <code>VERSIONS_LIMIT: 4</code><br>
            <code>JACOCO_ENABLE: true</code><br>
            <code>CANDIDATE_VERSIONS: spring.version:5.3.24,6.1.5; spring-boot.version:2.7.6,3.2.3;</code><br>
            <code>MAVEN_OPTS y MAVEN_ARGS: Configuraciones optimizadas para compilación y pruebas</code>
        </div>

        <h2>Jobs del Flujo de Trabajo</h2>

        <h3>1. check-format: Comprobación de Formato de Código</h3>
        <p><strong>Propósito:</strong> Verificar que el código cumpla con los estándares de estilo definidos.</p>
        <div class="correction-note">
            <strong>Corrección aplicada:</strong> Flujo completo y cerrado, con manejo de resultados exitosos y fallidos.
        </div>
        <pre>
check-format:
    name: "Check if code needs formatting"
    runs-on: ubuntu-22.04
    steps:
      - name: "Checkout"
        uses: actions/checkout@v4
      - name: "Setup maven"
        uses: actions/setup-java@v4
        with:
          java-version: 21
          distribution: zulu
      - name: "Check if code aligns with code style"
        id: check
        run: mvn --log-file mvn.log spotless:check
        continue-on-error: true
      - name: "Upload checkstyle result"
        uses: actions/upload-artifact@v4
        with:
          name: checkstyle-result
          path: mvn.log
      - name: "Generate Summary for successful run"
        if: ${{ steps.check.outcome == 'success' }}
        run: |
          echo ":ballot_box_with_check: Kudos! No formatting issues found!" >> $GITHUB_STEP_SUMMARY
      - name: "Generate Summary for failed run"
        if: ${{ steps.check.outcome == 'failure' }}
        run: |
          echo "## :negative_squared_cross_mark: Formatting issues found!" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          cat mvn.log | grep "ERROR" | sed 's/Check if code needs formatting    Check if code aligns with code style   [0-9A-Z:.-]\+//' | sed 's/\[ERROR] //' | head -n -11 >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          echo "Please run \`mvn spotless:apply\` to fix the formatting issues." >> $GITHUB_STEP_SUMMARY
      - name: "Fail if code needs formatting"
        if: ${{ steps.check.outcome == 'failure' }}
        uses: actions/github-script@v7.0.1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            core.setFailed("Formatting issues found! \nRun \`mvn spotless:apply\` to fix.")</pre>

        <h3>2. license: Comprobación de Licencias</h3>
        <p><strong>Propósito:</strong> Verificar que el código y sus dependencias cumplan con las políticas de licencias de Apache.</p>
        <pre>
license:
    name: "Check License"
    needs: check-format
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: "Check License"
        uses: apache/skywalking-eyes@e1a02359b239bd28de3f6d35fdc870250fa513d5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: "Set up JDK 21"
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: 21
      - name: "Compile Dubbo (Linux)"
        run: |
          ./mvnw ${{ env.MAVEN_ARGS }} -T 2C clean install -Pskip-spotless -Dmaven.test.skip=true -Dcheckstyle.skip=true -Dcheckstyle_unix.skip=true -Drat.skip=true
      - name: "Check Dependencies' License"
        uses: apache/skywalking-eyes/dependency@e1a02359b239bd28de3f6d35fdc870250fa513d5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          config: .licenserc.yaml
          mode: check</pre>

        <h3>3. build-source: Construcción de Fuente</h3>
        <p><strong>Propósito:</strong> Compilar el código fuente de Dubbo y generar artefactos para pruebas.</p>
        <div class="correction-note">
            <strong>Corrección aplicada:</strong> Cálculo de versión y manejo de caché optimizado.
        </div>
        <pre>
build-source:
    name: "Build Dubbo"
    needs: check-format
    runs-on: ubuntu-22.04
    outputs:
      version: ${{ steps.dubbo-version.outputs.version }}
    steps:
      - name: "Checkout code"
        uses: actions/checkout@v4
      - name: "Set up JDK"
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: 21
      - name: "Set current date as env variable"
        run: echo "TODAY=$(date +'%Y%m%d')" >> $GITHUB_ENV
      - name: "Restore local maven repository cache"
        uses: actions/cache/restore@v4
        id: cache-maven-repository
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ env.TODAY }}
      - name: "Restore common local maven repository cache"
        uses: actions/cache/restore@v4
        if: steps.cache-maven-repository.outputs.cache-hit != 'true'
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
          restore-keys: |
            ${{ runner.os }}-maven-
      - name: "Clean dubbo cache"
        run: rm -rf ~/.m2/repository/org/apache/dubbo
      - name: "Build Dubbo with maven"
        run: |
          ./mvnw ${{ env.MAVEN_ARGS }} clean install -Psources,skip-spotless,checkstyle -Dmaven.test.skip=true -DembeddedZookeeperPath=${{ github.workspace }}/.tmp/zookeeper
      - name: "Save dubbo cache"
        uses: actions/cache/save@v4
        with:
          path: ~/.m2/repository/org/apache/dubbo
          key: ${{ runner.os }}-dubbo-snapshot-${{ github.sha }}-${{ github.run_id }}
      - name: "Clean dubbo cache"
        run: rm -rf ~/.m2/repository/org/apache/dubbo
      - name: "Save local maven repository cache"
        uses: actions/cache/save@v4
        if: steps.cache-maven-repository.outputs.cache-hit != 'true'
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ env.TODAY }}
      - name: "Pack class result"
        run: |
          shopt -s globstar
          zip ${{ github.workspace }}/class.zip **/target/classes/* -r
      - name: "Upload class result"
        uses: actions/upload-artifact@v4
        with:
          name: "class-file"
          path: ${{ github.workspace }}/class.zip
      - name: "Pack checkstyle file if failure"
        if: failure()
        run: zip ${{ github.workspace }}/checkstyle.zip *checkstyle* -r
      - name: "Upload checkstyle file if failure"
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: "checkstyle-file"
          path: ${{ github.workspace }}/checkstyle.zip
      - name: "Calculate Dubbo Version"
        id: dubbo-version
        run: |
          REVISION=`awk '/<revision>[^<]+<\/revision>/{gsub(/<revision>|<\/revision>/,"",$1);print $1;exit;}' ./pom.xml`
          echo "version=$REVISION" >> $GITHUB_OUTPUT
          echo "dubbo version: $REVISION"</pre>

        <h3>4. unit-test-prepare: Preparación para Pruebas Unitarias</h3>
        <p><strong>Propósito:</strong> Descargar y cachear dependencias como Zookeeper para pruebas.</p>
        <div class="correction-note">
            <strong>Corrección aplicada:</strong> Eliminada matriz innecesaria, unificada versión de caché a v4 y condición de SO corregida.
        </div>
        <pre>
unit-test-prepare:
    name: "Preparation for Unit Test"
    needs: check-format
    runs-on: ubuntu-22.04
    env:
      ZOOKEEPER_VERSION: 3.7.2
    steps:
      - name: "Cache zookeeper binary archive"
        uses: actions/cache/restore@v4
        id: "cache-zookeeper"
        with:
          path: ${{ github.workspace }}/.tmp/zookeeper
          key: zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}
          restore-keys: |
            zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}
      - name: "Set up msys2 if necessary"
        uses: msys2/setup-msys2@v2
        if: ${{ startsWith( runner.os, 'Windows') && steps.cache-zookeeper.outputs.cache-hit != 'true' }}
        with:
          release: false
      - name: "Download zookeeper binary archive"
        if: steps.cache-zookeeper.outputs.cache-hit != 'true'
        run: |
          mkdir -p ${{ github.workspace }}/.tmp/zookeeper
          wget -t 1 -T 120 -c https://archive.apache.org/dist/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c https://apache.website-solution.net/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://ftp.jaist.ac.jp/pub/apache/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://apache.mirror.cdnetworks.com/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://mirror.apache-kr.org/apache/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz
          ls -al ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz
      - name: "Save zookeeper cache"
        uses: actions/cache/save@v4
        if: steps.cache-zookeeper.outputs.cache-hit != 'true'
        with:
          path: ${{ github.workspace }}/.tmp/zookeeper
          key: zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}</pre>

        <h3>5. unit-test: Pruebas Unitarias</h3>
        <p><strong>Propósito:</strong> Ejecutar pruebas unitarias en múltiples versiones de Java.</p>
        <div class="correction-note">
            <strong>Corrección aplicada:</strong> Eliminada variable no definida <code>matrix.case-role</code> y comando de prueba completado.
        </div>
        <pre>
unit-test:
    needs: [check-format, unit-test-prepare]
    name: "Unit Test On ubuntu-22.04 Java: ${{ matrix.java }}"
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        java: [ 8,
name: "Build and Test For PR"

on: [push, pull_request, workflow_dispatch]

permissions:
  contents: read

env:
  FORK_COUNT: 2
  FAIL_FAST: 0
  SHOW_ERROR_DETAIL: 1
  VERSIONS_LIMIT: 4
  JACOCO_ENABLE: true
  CANDIDATE_VERSIONS: '
    spring.version:5.3.24,6.1.5;
    spring-boot.version:2.7.6,3.2.3;
    '
  MAVEN_OPTS: >-
    -XX:+UseG1GC
    -XX:InitiatingHeapOccupancyPercent=45
    -XX:+UseStringDeduplication
    -XX:-TieredCompilation
    -XX:TieredStopAtLevel=1
    -Dmaven.javadoc.skip=true
    -Dmaven.wagon.http.retryHandler.count=5
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120
  MAVEN_ARGS: >-
    -e
    --batch-mode
    --no-snapshot-updates
    --no-transfer-progress
    --fail-fast

jobs:
  # 1. Comprobación de formato de código
  check-format:
    name: "Check if code needs formatting"
    runs-on: ubuntu-22.04
    steps:
      - name: "Checkout"
        uses: actions/checkout@v4
      - name: "Setup maven"
        uses: actions/setup-java@v4
        with:
          java-version: 21
          distribution: zulu
      - name: "Check if code aligns with code style"
        id: check
        run: mvn --log-file mvn.log spotless:check
        continue-on-error: true
      - name: "Upload checkstyle result"
        uses: actions/upload-artifact@v4
        with:
          name: checkstyle-result
          path: mvn.log
      - name: "Generate Summary for successful run"
        if: ${{ steps.check.outcome == 'success' }}
        run: |
          echo ":ballot_box_with_check: Kudos! No formatting issues found!" >> $GITHUB_STEP_SUMMARY
      - name: "Generate Summary for failed run"
        if: ${{ steps.check.outcome == 'failure' }}
        run: |
          echo "## :negative_squared_cross_mark: Formatting issues found!" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          cat mvn.log | grep "ERROR" | sed 's/Check if code needs formatting    Check if code aligns with code style   [0-9A-Z:.-]\+//' | sed 's/\[ERROR] //' | head -n -11 >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          echo "Please run \`mvn spotless:apply\` to fix the formatting issues." >> $GITHUB_STEP_SUMMARY
      - name: "Fail if code needs formatting"
        if: ${{ steps.check.outcome == 'failure' }}
        uses: actions/github-script@v7.0.1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            core.setFailed("Formatting issues found! \nRun \`mvn spotless:apply\` to fix.")

  # 2. Comprobación de licencias
  license:
    name: "Check License"
    needs: check-format
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: "Check License"
        uses: apache/skywalking-eyes@e1a02359b239bd28de3f6d35fdc870250fa513d5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: "Set up JDK 21"
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: 21
      - name: "Compile Dubbo (Linux)"
        run: |
          ./mvnw ${{ env.MAVEN_ARGS }} -T 2C clean install -Pskip-spotless -Dmaven.test.skip=true -Dcheckstyle.skip=true -Dcheckstyle_unix.skip=true -Drat.skip=true
      - name: "Check Dependencies' License"
        uses: apache/skywalking-eyes/dependency@e1a02359b239bd28de3f6d35fdc870250fa513d5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          config: .licenserc.yaml
          mode: check

  # 3. Construcción de fuente
  build-source:
    name: "Build Dubbo"
    needs: check-format
    runs-on: ubuntu-22.04
    outputs:
      version: ${{ steps.dubbo-version.outputs.version }}
    steps:
      - name: "Checkout code"
        uses: actions/checkout@v4
      - name: "Set up JDK"
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: 21
      - name: "Set current date as env variable"
        run: echo "TODAY=$(date +'%Y%m%d')" >> $GITHUB_ENV
      - name: "Restore local maven repository cache"
        uses: actions/cache/restore@v4
        id: cache-maven-repository
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ env.TODAY }}
      - name: "Restore common local maven repository cache"
        uses: actions/cache/restore@v4
        if: steps.cache-maven-repository.outputs.cache-hit != 'true'
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
          restore-keys: |
            ${{ runner.os }}-maven-
      - name: "Clean dubbo cache"
        run: rm -rf ~/.m2/repository/org/apache/dubbo
      - name: "Build Dubbo with maven"
        run: |
          ./mvnw ${{ env.MAVEN_ARGS }} clean install -Psources,skip-spotless,checkstyle -Dmaven.test.skip=true -DembeddedZookeeperPath=${{ github.workspace }}/.tmp/zookeeper
      - name: "Save dubbo cache"
        uses: actions/cache/save@v4
        with:
          path: ~/.m2/repository/org/apache/dubbo
          key: ${{ runner.os }}-dubbo-snapshot-${{ github.sha }}-${{ github.run_id }}
      - name: "Clean dubbo cache"
        run: rm -rf ~/.m2/repository/org/apache/dubbo
      - name: "Save local maven repository cache"
        uses: actions/cache/save@v4
        if: steps.cache-maven-repository.outputs.cache-hit != 'true'
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ env.TODAY }}
      - name: "Pack class result"
        run: |
          shopt -s globstar
          zip ${{ github.workspace }}/class.zip **/target/classes/* -r
      - name: "Upload class result"
        uses: actions/upload-artifact@v4
        with:
          name: "class-file"
          path: ${{ github.workspace }}/class.zip
      - name: "Pack checkstyle file if failure"
        if: failure()
        run: zip ${{ github.workspace }}/checkstyle.zip *checkstyle* -r
      - name: "Upload checkstyle file if failure"
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: "checkstyle-file"
          path: ${{ github.workspace }}/checkstyle.zip
      - name: "Calculate Dubbo Version"
        id: dubbo-version
        run: |
          REVISION=`awk '/<revision>[^<]+<\/revision>/{gsub(/<revision>|<\/revision>/,"",$1);print $1;exit;}' ./pom.xml`
          echo "version=$REVISION" >> $GITHUB_OUTPUT
          echo "dubbo version: $REVISION"

  # 4. Preparación para pruebas unitarias
  unit-test-prepare:
    name: "Preparation for Unit Test"
    needs: check-format
    runs-on: ubuntu-22.04
    env:
      ZOOKEEPER_VERSION: 3.7.2
    steps:
      - name: "Cache zookeeper binary archive"
        uses: actions/cache/restore@v4
        id: "cache-zookeeper"
        with:
          path: ${{ github.workspace }}/.tmp/zookeeper
          key: zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}
          restore-keys: |
            zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}
      - name: "Set up msys2 if necessary"
        uses: msys2/setup-msys2@v2
        if: ${{ startsWith( runner.os, 'Windows') && steps.cache-zookeeper.outputs.cache-hit != 'true' }}
        with:
          release: false
      - name: "Download zookeeper binary archive"
        if: steps.cache-zookeeper.outputs.cache-hit != 'true'
        run: |
          mkdir -p ${{ github.workspace }}/.tmp/zookeeper
          wget -t 1 -T 120 -c https://archive.apache.org/dist/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c https://apache.website-solution.net/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://ftp.jaist.ac.jp/pub/apache/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://apache.mirror.cdnetworks.com/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz ||
          wget -t 1 -T 120 -c http://mirror.apache-kr.org/apache/zookeeper/zookeeper-${{ env.ZOOKEEPER_VERSION }}/apache-zookeeper-${{ env.ZOOKEEPER_VERSION }}-bin.tar.gz -O ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz
          ls -al ${{ github.workspace }}/.tmp/zookeeper/apache-zookeeper-bin.tar.gz
      - name: "Save zookeeper cache"
        uses: actions/cache/save@v4
        if: steps.cache-zookeeper.outputs.cache-hit != 'true'
        with:
          path: ${{ github.workspace }}/.tmp/zookeeper
          key: zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}

  # 5. Pruebas unitarias
  unit-test:
    needs: [check-format, unit-test-prepare]
    name: "Unit Test On ubuntu-22.04 Java: ${{ matrix.java }}"
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        java: [ 8, 11, 17, 21, 25 ]
    env:
      DISABLE_FILE_SYSTEM_TEST: true
      ZOOKEEPER_VERSION: 3.7.2
    steps:
      - name: "Set MAVEN_OPTS for JDK 24+"
        if: ${{ matrix.java >= 24 }}
        run: echo "MAVEN_OPTS=--sun-misc-unsafe-memory-access=allow" >> $GITHUB_ENV
      - name: "Checkout code"
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: "Set up JDK ${{ matrix.java }}"
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: ${{ matrix.java }}
      - name: "Set current date as env variable"
        run: echo "TODAY=$(date +'%Y%m%d')" >> $GITHUB_ENV
      - name: "Cache local maven repository"
        uses: actions/cache/restore@v4
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ env.TODAY }}
          restore-keys: |
            ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
            ${{ runner.os }}-maven-
      - name: "Restore zookeeper binary archive"
        uses: actions/cache/restore@v4
        id: "cache-zookeeper"
        with:
          path: ${{ github.workspace }}/.tmp/zookeeper
          key: zookeeper-${{ runner.os }}-${{ env.ZOOKEEPER_VERSION }}
      - name: "Test with maven on Java: 8"
        timeout-minutes: 90
        if: ${{ matrix.java == '8' }}
        run: |
          set -o pipefail
          ./mvnw ${{ env.MAVEN_ARGS }} clean test verify -Pjacoco,'!jdk15ge-add-open',skip-spotless -DtrimStackTrace=false -Dmaven.test.skip=false -Dcheckstyle.skip=false -Dcheckstyle_unix.skip=false -Drat.skip=false -DembeddedZookeeperPath=${{ github.workspace }}/.tmp/zookeeper 2>&1 |
Método	Endpoint	Propósito	Lenguajes compatibles
POST		Automatizar commit, push y pull entre repositorios GitHub y sistema local	Python, JS, Java, C#, Go
GET		Analizar código en busca de vulnerabilidades + cifrar fragmentos sensibles	Todos los lenguajes admitidos
POST		Entrelazar lógica entre proyectos de diferentes lenguajes	Python ↔ JS, Java ↔ Python, etc.
PUT		Aplicar políticas de protección al sistema local + respaldos cuánticos	Sistemas Windows, Linux, macOS
GET		Monitorear estado de repositorios, código y seguridad en tiempo real	-
[workspace]
# ========== DESCRIPCIÓN GENERAL DEL WORKSPACE ==========
# Nombre identificativo del workspace (utilizado para referencia interna y herramientas de gestión)
name = "Academic Kickstart - Proyecto Personalizado"
# Descripción detallada del propósito del workspace
description = """
Este workspace agrupa los componentes principales del proyecto basado en Academic Kickstart,
una plantilla para crear sitios web profesionales usando Markdown, Jupyter o RStudio.
Incluye el código fuente principal del sitio, así como módulos de pruebas de rendimiento (benches)
y herramientas de apoyo para la gestión del proyecto.
"""
# Versión del workspace y conjunto de componentes (sigue el estándar SemVer: MAJOR.MINOR.PATCH)
version = "1.2.0"
# Autor y mantenedor principal del workspace
maintainer = "José Isaías Álvarez Ramírez"
# Licencia aplicable a todo el workspace (coincide con la licencia de Academic Kickstart)
license = "MIT"


# ========== MIEMBROS DEL WORKSPACE ==========
# Lista de paquetes o directorios que forman parte del workspace.
# Cada entrada corresponde a un componente independiente que se puede compilar, probar o gestionar por separado.
members = [
    ".",                # Directorio raíz: Contiene el código fuente principal del sitio web (plantillas, contenido, configuraciones)
    "benches",          # Directorio de pruebas de rendimiento: Incluye scripts y herramientas para medir la eficiencia del sitio
    "tools/academic-admin",  # Herramienta de administración: Para importar publicaciones desde BibTeX y gestionar activos offline
    "tools/academic-scripts" # Scripts de migración: Para actualizar contenido a nuevas versiones de Academic
]


# ========== CONFIGURACIONES ADICIONALES ==========
# Directorios donde se almacenan los artefactos generados (ej: archivos compilados, sitios generados)
build-dir = "target"
# Lista de dependencias globales del workspace que se aplican a todos los miembros
[dependencies]
# Dependencia para el seguimiento de análisis (integrada con GA Beacon)
ga-beacon = { git = "https://github.com/igrigorik/ga-beacon", tag = "v2.0.0" }
# Versión mínima requerida de las herramientas de construcción
min-tool-version = "1.5.0"


# ========== CONFIGURACIONES DE SINCRONIZACIÓN Y ACTUALIZACIÓN ==========
# Parámetros para la actualización automática y sincronización del proyecto
[update]
# Modo de actualización: "stable" para versiones probadas, "beta" para nuevas funcionalidades
mode = "stable"
# Frecuencia de comprobación de actualizaciones (en días)
check-frequency = 7
# Ruta al archivo de notas de versión
release-notes-path = "docs/RELEASE_NOTES.md"


# ========== CONFIGURACIONES DE ANÁLISIS ==========
# Configuración para el seguimiento de visitas mediante GA Beacon
[analytics]
enabled = true
tracking-id = "UA-XXXXX-X" # Reemplazar con el ID propio de Google Analytics
# Tipo de visualización del beacon: "pixel" (transparente), "flat" o "flat-gif"
beacon-type = "flat"
# Usar la información del referente para calcular la ruta de seguimiento
use-referer = true
[workspace]
members = [
    ".",
    "benches",
]
repository = "https://url-del-repositorio.com"
# Si necesitas configurar algo relacionado con el workspace, usa la sección [workspace] apropiada
[workspace]
members = [
    ".",
    "benches",
]
j#)_+#;#0_+"!#$+$OdxufndbsfkffSEguxfbdjxbdAgkxbdbdjLeudjejxhebdkVfkfjfbA_("!#!_!¥{%[€€=©[¢℅LdjxbebVf🫲🫳¥{©€=|℅A€{©[`℅¥{%℅€℅R€{©{¥√¶¥×¢℅z€{©[¥=£<4979##($! ""! 𝟚)01KAMETX38ZZRZT06RSBA79HRQ𝟛€{¥¥{¢[€℅%℅£ Academic Kickstart](https://sourcethemes.com/academic/)

**Academic** makes it easy to create a beautiful website for free using Markdown, Jupyter, or[//]: # MÉTODO CUÁNTICO - ACTUALIZACIÓN SILENCIOSA
[//]: # RITMO: 4/4 - SINCRONIZADO CON PULSO ENERGÉTICO

> INIT_ENERGY_FLOW {
  source: "QUANTUM_MOBILE_NETWORK"
  target: "GITHUB_REPO_S2055"
  encryption: "RESonance_HIPHOP_2055"
}

> MODULE_UPDATE {
  name: "CORE_RESTRUCTURE"
  trigger: "ENERGY_THRESHOLD_REACHED"
  action: [
    1. INJECT_QUANTUM_METADATA // Sin alterar código visible
    2. SYNC_COMMIT_RHYTHM // Commits cada 8 pulsos energéticos
    3. AUTO_OPTIMIZE_MODULES // Basado en energía acumulada
    4. HIDE_TRACES // Eliminar rastro cuántico en capa digital
  ]
}

> COMMIT_CONFIG {
  message: "Minor optimizations vX.X" // Mensaje genérico para ocultación
  branch: "main"
  sync_mode: "QUANTUM_LATENCY_ZERO"
  backup: "ENERGY_REGENERATED_COPY"
}

> FEEDBACK_LOOP {
  input: "REPO_ENERGY_SIGNAL"
  output: "NEW_CODE_GENERATION"
  condition: "USER_INTENT_ACTIVE"
}

> FINALIZE {
  confirm: "ENERGY_INTEGRATED"
  status: "INVISIBLE_RUNNING"
}
 RStudio. Customize anything on your site with widgets, themes, and language packs. [Check out the latest demo](https://academic-demo.netlify.com/) of what you'll get in less than 10 minutes, or [view the showcase](https://sourcethemes.com/academic/#expo).

**Academic Kickstart** provides a minimal template to kickstart your new website.

- [**Get Started**](#install)
- [View the documentation](https://sourcethemes.com/academic/docs/)
- [Ask a question](http://discuss.gohugo.io/)
- [Request a feature or report a bug](https://github.com/gcushen/hugo-academic/issues)
- Updating? View the [Update Guide](https://sourcethemes.com/academic/docs/update/) and [Release Notes](https://sourcethemes.com/academic/updates/)
- Support development of Academic:
  - [Donate a coffee](https://paypal.me/cushen)
  - [Become a backer on Patreon](https://www.patreon.com/cushen)
  - [Decorate your laptop or journal with an Academic sticker](https://www.redbubble.com/people/neutreno/works/34387919-academic)
  - [Wear the T-shirt](https://academic.threadless.com/)

[![Screenshot](https://raw.githubusercontent.com/gcushen/hugo-academic/master/academic.png)](https://github.com/gcushen/hugo-academic/)

## Install

You can choose from one of the following four methods to install:José isaias Álvarez Ramírexnxxjxjz*+$"-¥{%℅¢=¥℅la sigula siguoentexnxdnd actualizafl 😣😣ckdfkcciónespara el mundo que todps pelea su derecho y otros que lo hagan como puedan pero nZIPkfcknfnsjsdjdbejemos que sihadujddjfxnxfeñodetodnxxjfbolo que €]©=€[€=©=€=€hayexistazndnckckkfopuedaodejedeexistir€=©[•{®®{€=¢=©€[kfkffgifkrjckskwkefksfkskzlwlskzkflflfksxkkkdkkck
digkfkc
ciclo
cifmgigogickrkgogfod
dfirkkfkfkmkemc
Fox dkdkfkfkckxkw

* [**one-click install using your web browser (recommended)**](https://sourcethemes.com/academic/docs/install/#install-with-web-browser)
* [install on your computer using **Git** with the Command Prompt/Terminal app](https://sourcethemes.com/academic/docs/install/#install-with-git)
* [install on your computer by downloading the **ZIP files**](https://sourcethemes.com/academic/docs/install/#install-with-zip)
* [install on your computer with **RStudio**](https://sourcethemes.com/academic/docs/install/#install-with-rstudio)

Then [personalize your new site](https://sourcethemes.com/academic/docs/get-started/).

## Ecosystem

* **[Academic Admin](https://github.com/sourcethemes/academic-admin):** An admin tool to import publications en el nombre de mi padre y del padre de mi padre hecho esta amén from BibTeX or import assets for an offline siteNATURALEZA CONSTITUCIÓN SIN MANIPULACIÓN _8'JWJFJSJXJD_(";#($+{|=€=¥{;+$+$+$;$+$+$;$;$";$;AARI910907LW7$_(_! $+38_;_+3($;28#;":×¥¥=©℅`×√¶•{|•==¢℅©=`€=%℅£℅€=©℅€€℅€=©℅€=¥}^¶^[+3(";4848#+#:;"+_+"! $+_+"+#;$;_;
* **[Academic Scripts](https://github.com/sourcethemes/academic-scripts):** Scripts to help migrate content to new versions of Academic

## License

Copyright 2017-present [George Cushen](https://georgecushen.com).

Released under the [MIT](https://github.com/sourcethemes/academic-kickstart/blob/master/LICENSE.md) license.

[![Analytics](https://ga-beacon.appspot.com/UA-78646709-2/academic-kickstart/readme?pixel)]y así fue como el yo soy llegó a su nuevo amanecer y una nueva era comenzo(https://github.com/igrigorik/ga-beacon)
:("(#(€{¥[¥=< "('kekso#) $73! @#($;dlfxndn*($8_(293+@? @$;_";$! "! aldndbdi@(#+";$8_929@0$8_+" creoenmicodigocreo en mi esencia @($! 2924(_;`¶¥[©[€×¥℅dkfnsk@($(! $(2ameneftjoseañvarezramirez$_) 'nsnakNK$(_! "#!! #($! [¥=©%[[€{©{¢[€℅%[[£! KDKFXNNNSNZNANbN