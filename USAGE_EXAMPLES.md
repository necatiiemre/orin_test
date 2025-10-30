# Jetson Orin Test Suite - Usage Examples

## ✅ Interactive Prompts (Option C - IMPLEMENTED!)

All test scripts now ask for parameters interactively with defaults from command-line.

---

## Example 1: Running with NO parameters

```bash
$ ./jetson_cpu_test.sh

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]:           ← Press Enter for default
Username [orin]:                      ← Press Enter for default  
Password:                             ← Type password (hidden)
Test duration in hours [1]:           ← Press Enter for 1 hour

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.69
Username:         orin
Password:         ********
Test duration:    1 hours

Proceed with these settings? (yes/no) [yes]: ← Press Enter to proceed

✓ Configuration confirmed

[Test starts...]
```

---

## Example 2: Running with SOME parameters

```bash
$ ./jetson_gpu_test.sh 192.168.55.70 admin

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.70]:           ← Press Enter (uses 192.168.55.70)
Username [admin]:                     ← Press Enter (uses admin)
Password [using provided password]:   ← Press Enter or type new password
Test duration in hours [2]:           ← Type: 1.5 (override to 1.5 hours)

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.70
Username:         admin
Password:         ********
Test duration:    1.5 hours

Proceed with these settings? (yes/no) [yes]: yes

✓ Configuration confirmed

[Test starts with 1.5 hour duration...]
```

---

## Example 3: Running with ALL parameters

```bash
$ ./jetson_ram_test.sh 192.168.55.69 orin mypassword 2

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]:           ← Press Enter
Username [orin]:                      ← Press Enter
Password [using provided password]:   ← Press Enter
Test duration in hours [2]:           ← Press Enter

═══════════════════════════════════════════================================================================  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.69
Username:         orin
Password:         **********
Test duration:    2 hours

Proceed with these settings? (yes/no) [yes]: ← Press Enter

✓ Configuration confirmed

[Test starts...]
```

---

## Example 4: Changing everything interactively

```bash
$ ./jetson_storage_test.sh

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]: 192.168.55.100    ← Type new IP
Username [orin]: myuser                       ← Type new username
Password: ************                        ← Type password (hidden)
Test duration in hours [2]: 0.5               ← Type 30 minutes

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.100
Username:         myuser
Password:         ************
Test duration:    0.5 hours

Proceed with these settings? (yes/no) [yes]: yes

✓ Configuration confirmed

[Test starts with new settings...]
```

---

## Example 5: Cancelling a test

```bash
$ ./jetson_combined_parallel.sh

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]: 
Username [orin]: 
Password: ********
Test duration in hours [1]: 

═══════════════================================================================  TEST CONFIGURATION
═══════════════================================================================

Target IP:        192.168.55.69
Username:         orin
Password:         ********
Test duration:    1 hours

Proceed with these settings? (yes/no) [yes]: no    ← Type 'no' to cancel

[WARNING] Test cancelled by user
```

---

## All Test Scripts with Interactive Prompts

| Script | Default Duration | Description |
|--------|-----------------|-------------|
| `jetson_cpu_test.sh` | 1 hour | CPU stress test |
| `jetson_gpu_test.sh` | 2 hours | GPU stress test |
| `jetson_ram_test.sh` | 1 hour | RAM stress test |
| `jetson_storage_test.sh` | 2 hours | Storage stress test |
| `jetson_combined_sequential.sh` | 1 hour/component | Sequential combined test |
| `jetson_combined_parallel.sh` | 1 hour | Parallel combined test |

---

## Key Features

✅ **Shows defaults** - All parameters shown with current values  
✅ **Press Enter to accept** - Quick way to use defaults  
✅ **Type to override** - Can change any parameter  
✅ **Password masking** - Password is always hidden  
✅ **Confirmation screen** - Review before proceeding  
✅ **Cancel option** - Type 'no' to cancel  

---

## Benefits

- **No syntax to remember** - Just run the script!
- **Safe password entry** - Hidden input prevents shoulder surfing
- **Verify before running** - Review all settings before test starts
- **Quick defaults** - Press Enter 5 times for full defaults
- **Flexible** - Override any parameter you need
- **Error prevention** - Can't accidentally run wrong test

---

## Old Way vs New Way

### Old Way (required exact syntax):
```bash
./jetson_cpu_test.sh 192.168.55.69 orin mypassword 1
# Had to remember: IP, user, password, duration
# Password visible in command history!
```

### New Way (interactive):
```bash
./jetson_cpu_test.sh
# Shows prompts with defaults
# Press Enter to accept defaults
# Password is hidden
# Confirm before running
```

### Best of Both Worlds:
```bash
./jetson_cpu_test.sh 192.168.55.70
# Defaults to your IP
# Still asks for everything else
# Can override any parameter
```

---

## Quick Start

1. **Just run any test script:**
   ```bash
   ./jetson_cpu_test.sh
   ```

2. **Follow the prompts:**
   - See default values in square brackets `[like this]`
   - Press Enter to use default
   - Type new value to override

3. **Confirm and go:**
   - Review the configuration
   - Type `yes` or press Enter to proceed
   - Test starts!

---

That's it! No documentation to read, no syntax to remember - just run and follow the prompts! 🚀
