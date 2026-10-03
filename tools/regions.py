"""The three retail releases of Mario Power Tennis (New Play Control!) and their disc versions."""
REGIONS = {
    'RMAE01': dict(label='New Play Control! Mario Power Tennis (USA)', short='USA', version=0),
    'RMAP01': dict(label='New Play Control! Mario Power Tennis (Europe/Australia)', short='Europe', version=0),
    'RMAJ01': dict(label='New Play Control! Mario Power Tennis (Japan)', short='Japan', version=0),
}

# retail DOL sizes, to give a clear error on someone else's modified dump
DOL_SIZES = {'RMAE01': 1723968, 'RMAP01': 1723936, 'RMAJ01': 1633248}
