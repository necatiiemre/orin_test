# Interactive Prompts - How It Works

## Example Session

### Running with no parameters:
```bash
$ ./jetson_cpu_test.sh

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]:
Username [orin]:
Password: ********
Test duration in hours [1]:

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.69
Username:         orin
Password:         ********
Test duration:    1 hours

Proceed with these settings? (yes/no) [yes]:

✓ Configuration confirmed

[Test proceeds...]
```

### Running with some parameters:
```bash
$ ./jetson_cpu_test.sh 192.168.55.70 admin

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.70]: ← Press Enter to use 192.168.55.70
Username [admin]: ← Press Enter to use admin
Password [using provided password]: ← Can press Enter or type new password
Test duration in hours [1]: 2 ← Type 2 and press Enter

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.70
Username:         admin
Password:         ********
Test duration:    2 hours

Proceed with these settings? (yes/no) [yes]: yes

✓ Configuration confirmed

[Test proceeds with 2 hour duration...]
```

### Running with all parameters:
```bash
$ ./jetson_cpu_test.sh 192.168.55.69 orin mypassword 1.5

================================================================================
  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION
================================================================================

Enter test parameters (press Enter to use default):

IP Address [192.168.55.69]: ← Press Enter to accept
Username [orin]: ← Press Enter to accept
Password [using provided password]: ← Press Enter to accept
Test duration in hours [1.5]: ← Press Enter to accept

═══════════════════================================================================
  TEST CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Target IP:        192.168.55.69
Username:         orin
Password:         **********
Test duration:    1.5 hours

Proceed with these settings? (yes/no) [yes]: ← Press Enter to proceed

✓ Configuration confirmed

[Test proceeds...]
```

## Key Features

1. **Shows defaults** - All provided command-line parameters are shown as defaults
2. **Press Enter to accept** - Quick way to use defaults
3. **Type to override** - Can type new values if needed
4. **Password masking** - Password is hidden when typed
5. **Confirmation screen** - Review all settings before proceeding
6. **Cancel option** - Type 'no' at confirmation to cancel

## Benefits

- No need to remember exact syntax
- Can verify settings before test runs
- Safe password entry (hidden input)
- Quick to use with defaults
- Flexible to override any parameter
