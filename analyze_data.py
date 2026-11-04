import pandas as pd

df = pd.read_csv(r'd:\AppAir\TLTK_BCTN\Data_ThuDauMot_1Nam.csv')
df['time'] = pd.to_datetime(df['time'])

print('=== DU LIEU THUC TE THU DAU MOT ===')
print(f'Tu: {df.time.min()} den: {df.time.max()}')
print(f'Tong ban ghi: {len(df)}')

print('\n=== THONG KE PM2.5 (ug/m3) ===')
print(f'Trung binh: {df.pm2_5.mean():.2f}')
print(f'Trung vi: {df.pm2_5.median():.2f}')
print(f'Min: {df.pm2_5.min():.2f} | Max: {df.pm2_5.max():.2f}')
print(f'Do lech chuan: {df.pm2_5.std():.2f}')

print('\n=== PHAN LOAI THEO QCVN 05:2023 ===')
n = len(df)
tot = (df.pm2_5 <= 15).sum()
tb = ((df.pm2_5 > 15) & (df.pm2_5 <= 25)).sum()
kem = ((df.pm2_5 > 25) & (df.pm2_5 <= 50)).sum()
xau = (df.pm2_5 > 50).sum()
print(f'Tot    (<= 15):  {tot:5d} ({tot/n*100:.1f}%)')
print(f'Trung binh (15-25): {tb:5d} ({tb/n*100:.1f}%)')
print(f'Kem    (25-50):  {kem:5d} ({kem/n*100:.1f}%)')
print(f'Xau    (> 50):   {xau:5d} ({xau/n*100:.1f}%)')

mean_pm25 = df.pm2_5.mean()
rmse = 16.25
mae = 10.39
print(f'\n=== SO SANH SAI SO MO HINH ===')
print(f'RMSE={rmse} = {rmse/mean_pm25*100:.1f}% gia tri trung binh PM2.5')
print(f'MAE ={mae} = {mae/mean_pm25*100:.1f}% gia tri trung binh PM2.5')
print(f'PM2.5 trung binh khu vuc: {mean_pm25:.2f} ug/m3')
