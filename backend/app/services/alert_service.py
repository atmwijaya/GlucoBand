def check_abnormal(glucose_value):
    if glucose_value < 70:
        return 'hipoglikemia'
    elif glucose_value > 200:
        return 'hiperglikemia'
    return 'normal'