1. SMARTFactory and Forwarder are predeployed and subgraph listens to it

2. ADMINUSER signs up and runs through the onboarding wizard
3. ADMINUSER creates the systemvia the factory and becomes the system admin
4. ADMINUSER via the platform deploys the implementations (these are where the changes will be made for projects)
5. ADMINUSER registers the implementations on the System, which deploys the proxies, from this point the implementations can be upgraded over time if more changes are needed.

6. In the platform admin section, there is a management page:

   - Permission management on the system (would be great if the BetterAuth permissions actually came from the on chain permissions, like, get all permissions for a wallet, then check if there are admin permissions on system, if so, be an admin in better auth, are there token management or issuance permissions, if so issuer)
   - At some point we could do upgrade management here too, but that is out of scope for now

   - In the user management section, in the user permissions, a user can be given issuance rights on each of the registries, this will make them an issuer for that token.

7. When a user issues a token, we only give it the admin rights (aka the rights to manage permissions)
8. In that wizard, we have the permissions step where we need to make it a bit more obvious for the initial user that extra permissions need to be added for the user to do it all.
