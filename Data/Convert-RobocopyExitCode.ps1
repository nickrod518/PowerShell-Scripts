function Convert-RobocopyExitCode ($ExitCode) {
    switch ($ExitCode) {
        16 {'***FATAL ERROR***'}
        15 {'OKCOPY + FAIL + MISMATCHES + XTRA'}
        14 {'FAIL + MISMATCHES + XTRA'}
        13 {'OKCOPY + FAIL + MISMATCHES'}
        12 {'FAIL + MISMATCHES'}
        11 {'OKCOPY + FAIL + XTRA'}
        10 {'FAIL + XTRA'}
        9 {'OKCOPY + FAIL'}
        8 {'FAIL'}
        7 {'OKCOPY + MISMATCHES + XTRA'}
        6 {'MISMATCHES + XTRA'}
        5 {'OKCOPY + MISMATCHES'}
        4 {'MISMATCHES'}
        3 {'OKCOPY + XTRA'}
        2 {'XTRA'}
        1 {'OKCOPY'}
        0 {'No Change'}
        default {'Unknown'}
    }
}