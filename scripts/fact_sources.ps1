function Get-FactRtlSources {
  param([Parameter(Mandatory=$true)][string]$Root)

  $p520 = @(
    'p520_ntt46_mrec_params_pkg.sv',
    'p520_ntt46_mrec_arith_pkg.sv',
    'p520_ntt46_fact_forward_pair_to_product16_stream_bram_r512.sv',
    'p520_ntt46_fact_forward_pair_to_product32_stream_r512.sv',
    'p520_ntt46_fact_forward_pair_to_product64_stream_bram_r512.sv',
    'p520_ntt46_fact_forward64_to_product32_stream_r512.sv',
    'p520_ntt46_fact_lean_ip_int4_axi_lite_core.sv',
    'p520_ntt46_fact_lean_ip_int4_local_core.sv',
    'p520_ntt46_fact_lean_res_bank.sv',
    'p520_ntt46_fact_pair_inverse_terminal_shared_r512.sv',
    'p520_ntt46_fact_runtime_shared_pair_product16_streamed_bram_r512.sv',
    'p520_ntt46_fact_terminal_crt_recombine32_r512.sv',
    'p520_ntt46_fact_top_prod_load16.sv',
    'p520_ntt46_mrec_modmul_j_pipe.sv',
    'p520_ntt46_mrec_modmul_pipe.sv',
    'p520_ntt46_mrec_modmul_tight_pipe.sv',
    'p520_ntt46_zest_batch64_store_r512.sv',
    'p520_ntt46_zest_radix24_bidir_bfly_lane_pipe.sv',
    'p520_ntt46_zest_radix24_bidir_bfly_lane_unified_pipe.sv',
    'p520_ntt46_zest_radix24_lane16_group.sv',
    'p520_ntt46_zest_radix24_lane16_group_unified_probe.sv',
    'p520_ntt46_zest_radix24_step16.sv',
    'p520_ntt46_zest_radix24_twiddle16_rom.sv',
    'p520_ntt46_zest_slot16_store_sameaddr.sv'
  )

  $p254 = @(
    'ntt46_mrec_params_pkg.sv',
    'ntt46_mrec_arith_pkg.sv',
    'ntt46_mrec_modmul_pipe.sv',
    'ntt46_mrec_modmul_tight_pipe.sv',
    'ntt46_mrec_modmul_j_pipe.sv',
    'ntt46_zest_batch64_store_r512.sv',
    'ntt46_zest_radix24_twiddle16_rom.sv',
    'ntt46_zest_radix24_bidir_bfly_lane_pipe.sv',
    'ntt46_zest_radix24_lane16_group.sv',
    'ntt46_zest_radix24_bidir_bfly_lane_unified_pipe.sv',
    'ntt46_zest_radix24_lane16_group_unified_probe.sv',
    'ntt46_zest_radix24_step16.sv',
    'ntt46_zest_slot16_store_sameaddr.sv',
    'ntt46_fact_terminal_crt_recombine32_r512.sv',
    'ntt46_fact_pair_inverse_terminal_shared_r512.sv',
    'ntt46_fact_forward_pair_to_product16_stream_bram_r512.sv',
    'ntt46_fact_forward64_to_product32_stream_r512.sv',
    'ntt46_fact_forward_pair_to_product32_stream_r512.sv',
    'ntt46_fact_forward_pair_to_product64_stream_bram_r512.sv',
    'ntt46_fact_runtime_shared_pair_product16_streamed_bram_r512.sv',
    'ntt46_fact_top_prod_load16.sv',
    'ntt46_fact_lean_res_bank.sv',
    'ntt46_fact_lean_ip_int4_local_core.sv'
  )

  $unified = @(
    'ntt46_fact_lean_ip_int8_parallel_prime_core.sv',
    'ntt46_fact_lean_ip_int8_axi_lite_core.sv',
    'ntt46_fact_lean_ip_unified_axi_lite_core.sv'
  )

  $files = @()
  $files += $p520 | ForEach-Object { Join-Path $Root "rtl/p520/$_" }
  $files += $p254 | ForEach-Object { Join-Path $Root "rtl/p254/$_" }
  $files += Join-Path $Root 'rtl/common/ntt46_fact_ip_v1_crt2_reconstruct.sv'
  $files += $unified | ForEach-Object { Join-Path $Root "rtl/unified/$_" }

  foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing RTL source: $file" }
  }
  return $files
}

function Resolve-FactTool {
  param(
    [string]$ExplicitPath,
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$EnvironmentName
  )
  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    $candidate = if (Test-Path -LiteralPath $ExplicitPath -PathType Container) {
      Join-Path $ExplicitPath $Executable
    } else { $ExplicitPath }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path $candidate).Path }
    throw "$Executable was not found at $candidate"
  }
  $command = Get-Command $Executable -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $command) {
    throw "$Executable was not found. Add it to PATH, set $EnvironmentName, or pass an explicit tool path."
  }
  return $command.Source
}

function Resolve-FactPython {
  param([string]$ExplicitPath)
  $paths = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
      $paths.Add((Resolve-Path -LiteralPath $ExplicitPath).Path)
    } else {
      $command = Get-Command $ExplicitPath -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        $paths.Add($command.Source)
      }
    }
  }
  else {
    foreach ($name in @('python.exe','python3.exe','python','python3','py.exe','py')) {
      $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($null -ne $command) { $paths.Add($command.Source) }
    }
  }
  foreach ($path in $paths) {
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    try {
      & $path --version *> $null
      if ($LASTEXITCODE -eq 0) { return (Resolve-Path -LiteralPath $path).Path }
    } catch {
      continue
    }
  }
  throw 'A working Python 3 interpreter was not found. Add it to PATH, set PYTHON, or pass an explicit path.'
}

function Initialize-FactRomWorkspace {
  param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$WorkDir
  )
  $pairs = @(
    @('rom/p254/zest_schedule','rom/zest_schedule'),
    @('rom/p254/fact','rom/fact'),
    @('rom/p520/zest_schedule','rom_p520/zest_schedule'),
    @('rom/p520/fact','rom_p520/fact')
  )
  foreach ($pair in $pairs) {
    $source = Join-Path $Root $pair[0]
    $destination = Join-Path $WorkDir $pair[1]
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -Path (Join-Path $source '*.mem') -Destination $destination -Force
  }
}
