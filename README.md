# x402 lint — GitHub Action

Checks your [x402](https://x402.org) paid endpoints the way buyers' agents and catalogues see them,
and fails the build when the payment terms are broken.

One unpaid request per URL, then the 402 terms against the spec (v2 `PAYMENT-REQUIRED` header and
v1 body), network ids, EIP-712 domain, Solana `feePayer`, bazaar extension, CORS, the payment
address against your catalogue listing and OFAC, and `x-payment-info` in your openapi. Every
problem comes with a fix. Same checks as <https://alalanet.com/lint>.

```yaml
- uses: alalanet/x402-lint-action@v1
  with:
    urls: |
      https://api.example.com/paid
      https://api.example.com/other
    # method: GET        # or POST
    # fail-on: fail      # or warn
    # token: ${{ secrets.ALALANET_TOKEN }}   # optional, seller plan: 5,000 lints/day
```

Run it after deploy (the endpoint must be reachable from the internet). Problems show as
annotations and a table in the job summary; the `verdict` output is `pass`, `warn` or `fail`.

Free without a token: 100 lints per day per runner IP, one lint per host every 10 seconds
(the action waits and retries).

Needs `bash`, `curl` and `jq` (present on GitHub-hosted runners).

## Privacy

The action sends only the URLs you list to alalanet.com. alalanet makes one unpaid request to each
URL. No code, secrets or repository data leave the runner.

License: MIT-0.
