'use client'

import { useEffect, useRef } from 'react'

interface Props {
  points: { close: number | null }[]
  positive?: boolean
  width?: number
  height?: number
}

export default function MiniSparkline({ points, positive, width = 80, height = 32 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const closes = points.map(p => p.close).filter((c): c is number => c !== null)
    if (closes.length < 2) return

    const dpr = window.devicePixelRatio || 1
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = width + 'px'
    canvas.style.height = height + 'px'

    const ctx = canvas.getContext('2d')!
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, width, height)

    const min = Math.min(...closes)
    const max = Math.max(...closes)
    const range = max - min || 1
    const pad = 3

    const toX = (i: number) => pad + (i / (closes.length - 1)) * (width - pad * 2)
    const toY = (v: number) => pad + (1 - (v - min) / range) * (height - pad * 2)

    const isUp = closes[closes.length - 1]! >= closes[0]!
    const lineColor = isUp ? '#5fcb95' : '#e68078'
    const fillColor = isUp ? 'rgba(95,203,149,0.08)' : 'rgba(230,128,120,0.08)'

    // Fill area
    ctx.beginPath()
    ctx.moveTo(toX(0), height)
    closes.forEach((c, i) => ctx.lineTo(toX(i), toY(c)))
    ctx.lineTo(toX(closes.length - 1), height)
    ctx.closePath()
    ctx.fillStyle = fillColor
    ctx.fill()

    // Line
    ctx.beginPath()
    closes.forEach((c, i) => {
      if (i === 0) ctx.moveTo(toX(i), toY(c))
      else ctx.lineTo(toX(i), toY(c))
    })
    ctx.strokeStyle = lineColor
    ctx.lineWidth = 1.5
    ctx.lineJoin = 'round'
    ctx.stroke()
  }, [points, width, height, positive])

  return <canvas ref={canvasRef} style={{ display: 'block' }} />
}
