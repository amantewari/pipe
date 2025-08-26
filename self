name: CI Pipeline

on:
  workflow_dispatch:
    inputs:
      PHASE:
        description: 'Pipeline phase (BUILD, INSTALL, SONAR, SAST, DAST)'
        required: true
        default: 'BUILD'
      TEAMUP_ENV:
        description: 'TeamUp Environment (production/test)'
        required: true
        default: 'test'
      TARGET_ENV:
        description: 'Target Environment (TEST/DEV/PROD/DR)'
        required: true
        default: 'DEV'
      GIT_REV:
        description: 'Git revision to build'
        required: true
        default: 'HEAD'

jobs:
  build:
    if: ${{ github.event.inputs.PHASE == 'BUILD' }}
    runs-on: [self-hosted, linux, swm]   # labels of your runner
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
        with:
          ref: ${{ github.event.inputs.GIT_REV }}

      - name: Build with Ant
        run: ant -f trunk/build.xml build create.package

      - name: Create SWM Package
        run: |
          export AFTSWM_USERNAME=${{ secrets.AFTSWM_USERNAME }}
          export AFTSWM_PASSWORD=${{ secrets.AFTSWM_PASSWORD }}
          /opt/app/swm/aftswmcli/bin/swmcli component pkgcreate \
            -c com.att.soegcmi:soegcmi-all:1-SOEGCMI_${{ github.ref_name }}.${{ github.sha }} \
            -d /opt/app/soegcmi/smogtemplate

      - name: Send Dora Metrics (Build)
        run: echo "TODO: Implement Dora metrics reporting here"

  install:
    if: ${{ github.event.inputs.PHASE == 'INSTALL' }}
    runs-on: [self-hosted, linux, swm]
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.inputs.GIT_REV }}

      - name: Install Package
        run: |
          chmod +x trunk/jenkins_install.sh
          ./trunk/jenkins_install.sh \
            ${{ github.event.inputs.GIT_REV }} \
            ${{ github.event.inputs.TARGET_ENV }} \
            ${{ github.ref_name }}

      - name: Send Dora Metrics (Deploy)
        run: echo "TODO: Implement Dora metrics reporting here"

  sonar:
    if: ${{ github.event.inputs.PHASE == 'SONAR' }}
    runs-on: [self-hosted, linux, swm]
    steps:
      - uses: actions/checkout@v3
      - name: SonarQube Scan
        run: |
          export SONAR_SCANNER_HOME=/opt/sonar-scanner
          $SONAR_SCANNER_HOME/bin/sonar-scanner \
            -Dsonar.projectKey=SOEG-CMI \
            -Dsonar.host.url=${{ secrets.SONAR_HOST_URL }} \
            -Dsonar.login=${{ secrets.SONAR_TOKEN }}

  sast:
    if: ${{ github.event.inputs.PHASE == 'SAST' }}
    runs-on: [self-hosted, linux, swm]
    steps:
      - uses: actions/checkout@v3
      - name: Build with Ant for Veracode
        run: ant -f trunk/build.xml build create.package
      - name: Veracode Upload & Scan
        uses: veracode/veracode-uploadandscan-action@main
        with:
          appname: "19066-SOEG-CMI"
          createprofile: true
          version: ${{ github.run_id }}
          filepath: "trunk/smog/SmogBuild/dist/SmogEar.ear"
          vid: ${{ secrets.VERACODE_API_ID }}
          vkey: ${{ secrets.VERACODE_API_KEY }}

  dast:
    if: ${{ github.event.inputs.PHASE == 'DAST' }}
    runs-on: [self-hosted, linux, swm]
    steps:
      - uses: actions/checkout@v3
      - name: Run DAST Scan
        run: |
          if [ -f dast-config.yaml ]; then
            echo "Reading DAST config..."
            cat dast-config.yaml
            # Replace below with actual DAST CLI/scan command
            echo "Running DAST scan..."
          else
            echo "No dast-config.yaml found, skipping."
          fi