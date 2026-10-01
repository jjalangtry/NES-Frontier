; 8x16 sprite count, then horizontal offset, vertical offset, even tile, palette
enterprisetile = $02
enterprisesprites:
  .db $0B
  .db $00, $00, $02, $00
  .db $08, $00, $04, $00
  .db $10, $00, $06, $00
  .db $18, $00, $08, $03
  .db $20, $00, $0A, $00
  .db $28, $00, $0C, $00
  .db $08, $10, $0E, $00
  .db $10, $10, $10, $00
  .db $18, $10, $12, $00
  .db $20, $10, $14, $00
  .db $28, $10, $16, $00
klingontile = $18
klingonsprites:
  .db $07
  .db $00, $00, $18, $01
  .db $08, $00, $1A, $01
  .db $10, $00, $1C, $01
  .db $18, $00, $1E, $01
  .db $20, $00, $20, $01
  .db $18, $10, $22, $01
  .db $20, $10, $24, $01
asteroidtile = $26
asteroidsprites:
  .db $02
  .db $00, $00, $26, $02
  .db $08, $00, $28, $02
asteroidlargetile = $2A
asteroidlargesprites:
  .db $06
  .db $00, $00, $2A, $02
  .db $08, $00, $2C, $02
  .db $10, $00, $2E, $02
  .db $00, $10, $30, $02
  .db $08, $10, $32, $02
  .db $10, $10, $34, $02
torpedotile = $36
torpedosprites:
  .db $01
  .db $00, $00, $36, $03
torpedoalttile = $38
torpedoaltsprites:
  .db $01
  .db $00, $00, $38, $03
disruptortile = $3A
disruptorsprites:
  .db $01
  .db $00, $00, $3A, $01
shieldtile = $3C
shieldsprites:
  .db $01
  .db $00, $00, $3C, $00
shieldemptytile = $3E
shieldemptysprites:
  .db $01
  .db $00, $00, $3E, $00
shieldfieldtile = $40
shieldfieldsprites:
  .db $02
  .db $00, $00, $40, $00
  .db $00, $10, $42, $00
impulsetile = $44
impulsesprites:
  .db $01
  .db $00, $00, $44, $00
explosiontile = $46
explosionsprites:
  .db $02
  .db $00, $00, $46, $03
  .db $08, $00, $48, $03
explosionalttile = $4A
explosionaltsprites:
  .db $02
  .db $00, $00, $4A, $03
  .db $08, $00, $4C, $03
pauseicontile = $4E
pauseiconsprites:
  .db $02
  .db $00, $00, $4E, $00
  .db $08, $00, $50, $00
resumeicontile = $52
resumeiconsprites:
  .db $02
  .db $00, $00, $52, $00
  .db $08, $00, $54, $00
restarticontile = $56
restarticonsprites:
  .db $02
  .db $00, $00, $56, $00
  .db $08, $00, $58, $00
menucursortile = $5A
menucursorsprites:
  .db $01
  .db $00, $00, $5A, $00
beststartile = $5C
beststarsprites:
  .db $01
  .db $00, $00, $5C, $00
meter0tile = $5E
meter0sprites:
  .db $01
  .db $00, $00, $5E, $00
heatmeter0tile = $60
heatmeter0sprites:
  .db $01
  .db $00, $00, $60, $00
meter1tile = $62
meter1sprites:
  .db $01
  .db $00, $00, $62, $00
heatmeter1tile = $64
heatmeter1sprites:
  .db $01
  .db $00, $00, $64, $00
meter2tile = $66
meter2sprites:
  .db $01
  .db $00, $00, $66, $00
heatmeter2tile = $68
heatmeter2sprites:
  .db $01
  .db $00, $00, $68, $00
meter3tile = $6A
meter3sprites:
  .db $01
  .db $00, $00, $6A, $00
heatmeter3tile = $6C
heatmeter3sprites:
  .db $01
  .db $00, $00, $6C, $00
meter4tile = $6E
meter4sprites:
  .db $01
  .db $00, $00, $6E, $00
heatmeter4tile = $70
heatmeter4sprites:
  .db $01
  .db $00, $00, $70, $00
meter5tile = $72
meter5sprites:
  .db $01
  .db $00, $00, $72, $00
heatmeter5tile = $74
heatmeter5sprites:
  .db $01
  .db $00, $00, $74, $00
meter6tile = $76
meter6sprites:
  .db $01
  .db $00, $00, $76, $00
heatmeter6tile = $78
heatmeter6sprites:
  .db $01
  .db $00, $00, $78, $00
meter7tile = $7A
meter7sprites:
  .db $01
  .db $00, $00, $7A, $00
heatmeter7tile = $7C
heatmeter7sprites:
  .db $01
  .db $00, $00, $7C, $00
meter8tile = $7E
meter8sprites:
  .db $01
  .db $00, $00, $7E, $00
heatmeter8tile = $80
heatmeter8sprites:
  .db $01
  .db $00, $00, $80, $00
metertiles:
  .db meter0tile,meter1tile,meter2tile,meter3tile,meter4tile,meter5tile,meter6tile,meter7tile,meter8tile
hottiles:
  .db heatmeter0tile,heatmeter1tile,heatmeter2tile,heatmeter3tile,heatmeter4tile,heatmeter5tile,heatmeter6tile,heatmeter7tile,heatmeter8tile
; Beam masks are in background pattern table $1000.
beamhmain:
  .db $04,$06,$08,$0A,$0C,$0E,$10,$12,$04,$06,$08,$0A,$0C,$0E,$10,$12
  .db $04,$06,$08,$16,$17,$18,$19,$1A,$04,$06,$1D,$1F,$21,$22,$23,$24
  .db $04,$26,$28,$29,$2A,$2B,$2C,$2D,$04,$26,$30,$32,$33,$34,$35,$36
  .db $04,$38,$3A,$3B,$3C,$3D,$3E,$3F,$04,$41,$42,$43,$44,$45,$46,$47
  .db $48,$49,$4A,$4B,$4C,$4D,$4E,$4F,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
  .db $50,$51,$52,$53,$54,$55,$56,$57,$59,$5A,$5B,$5C,$5D,$5E,$5F,$61
  .db $63,$64,$65,$66,$67,$68,$69,$6B,$6D,$6E,$6F,$70,$71,$73,$69,$6B
  .db $77,$78,$79,$7A,$7B,$7D,$7F,$6B,$82,$83,$84,$85,$86,$7D,$7F,$6B
  .db $8B,$8C,$8D,$8E,$8F,$90,$91,$92
beamhspill:
  .db $05,$07,$09,$0B,$0D,$0F,$11,$00,$05,$07,$09,$0B,$0D,$0F,$11,$00
  .db $13,$14,$15,$0D,$0F,$11,$00,$00,$1B,$1C,$1E,$20,$11,$00,$00,$00
  .db $25,$27,$20,$11,$00,$00,$00,$00,$2E,$2F,$31,$00,$00,$00,$00,$00
  .db $37,$39,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$58,$00,$00,$00,$00,$00,$00,$60,$62
  .db $00,$00,$00,$00,$00,$60,$6A,$6C,$00,$00,$00,$00,$72,$74,$75,$76
  .db $00,$00,$00,$72,$7C,$7E,$80,$81,$00,$00,$72,$7C,$87,$88,$89,$8A
  .db $00,$72,$7C,$87,$88,$89,$8A,$93
beamvmain:
  .db $04,$06,$08,$0A,$0C,$0E,$10,$12,$00,$00,$00,$00,$00,$00,$00,$00
  .db $04,$06,$08,$97,$98,$99,$9A,$9B,$00,$00,$00,$00,$00,$00,$00,$00
  .db $04,$9D,$9F,$A1,$A2,$A3,$A4,$A5,$00,$00,$00,$00,$00,$00,$00,$00
  .db $04,$A7,$A9,$AA,$AB,$AC,$AD,$AE,$00,$00,$00,$00,$00,$00,$00,$00
  .db $AF,$B0,$B1,$B2,$B3,$B4,$B5,$B6,$00,$00,$00,$00,$00,$00,$00,$00
  .db $B7,$B8,$B9,$BA,$BB,$BC,$BD,$BE,$00,$00,$00,$00,$00,$00,$00,$00
  .db $C0,$C1,$C2,$C3,$C4,$C5,$C7,$C9,$00,$00,$00,$00,$00,$00,$00,$00
  .db $CB,$CC,$CD,$CE,$CF,$D0,$D2,$C9,$00,$00,$00,$00,$00,$00,$00,$00
  .db $8B,$93,$8A,$89,$88,$87,$7C,$72
beamvspill:
  .db $05,$07,$09,$0B,$0D,$0F,$11,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $94,$95,$96,$0D,$0F,$11,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $9C,$9E,$A0,$11,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $A6,$A8,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$BF,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$C6,$C8,$CA,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$92,$91,$D1,$D3,$D4,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$92,$91,$90,$8F,$8E,$8D,$8C
healthtiles:
  .db $D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD
menutiles:
  .db $00, $DE, $DF, $E0, $E1, $E2, $E3, $E4, $E5
digitpairtiles:
  .db $82,$84,$86,$88,$8A,$86,$8C,$8E,$90,$92,$84,$94,$96,$98,$9A,$96
  .db $9C,$9E,$A0,$A2,$86,$96,$A4,$A6,$A8,$AA,$AC,$AE,$B0,$B2,$B4,$B6
  .db $B8,$BA,$BC,$B8,$BE,$C0,$C2,$C4,$C6,$C8,$CA,$CC,$CE,$D0,$D2,$D4
  .db $D6,$D8,$86,$96,$AA,$A6,$DA,$A4,$DC,$DE,$B0,$E0,$92,$A2,$B2,$E2
  .db $E4,$E0,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE,$E7
  .db $90,$A0,$B0,$E9,$EB,$B0,$ED,$EF,$F1,$EA,$8C,$9C,$AC,$F3,$F5,$DC
  .db $F7,$F9,$ED,$E6
digitpairattributes:
  .db $00,$40,$C0,$40,$C0,$40,$40,$C0,$00,$C0,$00,$00,$00,$00,$80,$80
  .db $00,$80,$00,$80,$00,$C0,$00,$00,$C0,$00,$00,$C0,$00,$00,$00,$40
  .db $00,$00,$C0,$80,$00,$C0,$00,$80,$80,$80,$80,$80,$80,$80,$80,$80
  .db $80,$80,$80,$40,$80,$80,$C0,$40,$40,$C0,$80,$80,$00,$40,$C0,$40
  .db $C0,$40,$40,$C0,$00,$00,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
  .db $40,$40,$C0,$40,$C0,$40,$40,$C0,$00,$C0,$80,$C0,$C0,$80,$C0,$80
  .db $40,$C0,$80,$80
