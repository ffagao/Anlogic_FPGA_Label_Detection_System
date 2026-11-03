"""Run the important-module suite against the submitted RTL."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent
if not str(root).isascii():
    raise SystemExit('Copy the entire FPGA project to an ASCII path, e.g. E:/contest_fpga, then retry.')
cases = [
    'tb_v42_dynamic_controller', 'tb_v43_barcode', 'tb_v43_barcode_pixels',
    'tb_uart_telemetry', 'tb_motion_region_counter', 'tb_motion_regions_stream',
    'tb_v34_video', 'tb_v39_control', 'tb_v41_caption', 'tb_v41_metrics',
    'tb_v33_learning', 'tb_v34_histogram60', 'tb_v20_ae_chain',
    'tb_v23_awb_green_bias', 'tb_hud_cache',
]
raise SystemExit(subprocess.call([sys.executable, str(root / 'run_v34_tests.py'), *cases]))
