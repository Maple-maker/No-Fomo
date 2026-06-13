import 'dotenv/config'
import { backfillCharts } from '../lib/backfillCharts'

const dryRun = process.argv.includes('--apply') ? false : true

backfillCharts(dryRun)
  .then(result => {
    console.log(JSON.stringify(result, null, 2))
    process.exit(result.errors.length > 0 ? 1 : 0)
  })
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
